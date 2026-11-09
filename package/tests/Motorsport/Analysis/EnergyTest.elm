module Motorsport.Analysis.EnergyTest exposing (suite)

import Expect
import Motorsport.Analysis.Energy as Energy exposing (Energy(..))
import Motorsport.Analysis.Strategy as Strategy
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race.Car exposing (Car)
import Motorsport.Wec.Class as Class exposing (Class)
import Motorsport.Wec.Era as Era
import Test exposing (Test, describe, test)


{-| The fixtures are built so the plan comes out of a whole number of laps and the
reading is a subtraction a test can do in its head: wherever a test says nothing to
the contrary the class's plan is 10 laps, its ceiling 10 with it -- every car coming in
on the same lap -- and the car being read has run a first stint of 10 and stopped,
which is the eleventh clean run the pool is read from.

The clock asks one question -- where the car stands on its energy -- and never the plan: a class's plan is the finished race's, so a test may ask about any lap it likes and read the subtraction off the same ten laps.
-}
suite : Test
suite =
    describe "Motorsport.Analysis.Energy"
        [ describe "the class's plan"
            [ test "is the block its stops mostly fell in, and its top is kept apart from it" <|
                \_ ->
                    -- Nine cars ran 10 laps and three ran 13, the reading car's own
                    -- first stint one of the thirteens: the plan is the ten the class
                    -- mostly ran, the thirteen the ceiling carried beside it, and the
                    -- cars that went thirteen are read as overruns.
                    energyOf (slowFleet ++ [ runner [ run 13, stint 3 ] ]) 18
                        |> Maybe.map (\reading -> ( planOf reading, ceilingOf reading ))
                        |> Expect.equal (Just ( 10, 13))
            , test "and no reading while the class has fewer than ten clean stopped runs" <|
                \_ ->
                    -- Eight cars and the reading car's own first stint: nine clean
                    -- runs, one short of the ten a class needs before its stops say
                    -- anything at all.
                    energyOf (fleetOf 8 10 ++ [ runner [ run 10, stint 3 ] ]) 15
                        |> Expect.equal (Just Unreadable)
            , test "is not read from a run the field was held down for" <|
                \_ ->
                    -- Ten clean runs of 10, and nine of 40 that met a procedure on
                    -- the way, all of them in the past by the lap asked about: the
                    -- long runs are what a caution is worth, not what the energy is
                    -- worth, so the plan stays 10.
                    energyOf (fleet ++ heldFleet ++ [ runner [ run 10, stint 33 ] ]) 45
                        |> Maybe.map planOf
                        |> Expect.equal (Just 10)
            , test "is the same plan at the first lap as at the flag" <|
                \_ ->
                    -- The class's word is the whole race's, which is what lets a
                    -- column of cars be drawn from one reading of it; the clock moves
                    -- the car along its energy and never moves the plan.
                    let
                        cars =
                            fleet ++ [ runner [ run 10, stint 3 ] ]
                    in
                    ( energyOf cars 3 |> Maybe.map planOf
                    , energyOf cars 15 |> Maybe.map planOf
                    )
                        |> Expect.equal ( Just 10, Just 10 )
            , test "is a block a quarter of itself wide, and no plan past that" <|
                \_ ->
                    -- A class that comes in on 9, 10 and 11 disagrees by one lap of a ten-lap plan, which is inside the gate, and is read as a level with a one-lap band.
                    -- A class spreading from 6 to 15 disagrees by two laps of the same plan, which is past it: the answer becomes the class's own stops -- quarters at 8 and 12, middle stop on 10, longest run 14.
                    let
                        tight =
                            fleetRunning [ 9, 9, 9, 10, 10, 10, 11, 11, 11 ]

                        wide =
                            fleetRunning [ 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 ]
                    in
                    ( energyOf (tight ++ [ runner [ run 10, stint 3 ] ]) 15 |> Maybe.map (\reading -> ( planOf reading, bandOf reading ))
                    , energyOf (wide ++ [ runner [ run 10, stint 3 ] ]) 15 |> Maybe.map spreadOf
                    )
                        |> Expect.equal
                            ( Just ( 10, 1 )
                            , Just { low = 8, high = 12, median = 10, ceiling = 14 }
                            )
            , test "is not a block that does not carry the class" <|
                \_ ->
                    -- Four blocks of stops, at 8, 12, 16 and 20 laps, none holding two fifths of the class: that is a class running three plans at once, and the largest block is not its plan however tight the block itself is.
                    energyOf (fleetRunning [ 8, 8, 8, 12, 12, 12, 16, 16, 16, 20 ] ++ [ runner [ run 20, stint 1 ] ]) 25
                        |> Maybe.map spreadOf
                        |> Expect.equal (Just { low = 8, high = 16, median = 12, ceiling = 20 })
            , test "is no plan at all where the class stopped in a scramble" <|
                \_ ->
                    -- A class that comes in on three laps every time has a plan shorter than the shortest this column counts down.
                    energyOf (fleetRunning (List.repeat 10 3) ++ [ runner [ run 3, stint 1 ] ]) 5
                        |> Maybe.map spreadOf
                        |> Expect.equal (Just { low = 3, high = 3, median = 3, ceiling = 3 })
            , test "stands within a lap of the cycle Strategy reads off the same stops" <|
                \_ ->
                    -- Strategy counts the lap into the pits and Energy does not, which
                    -- is the whole of the difference between the two, and no more.
                    let
                        cars =
                            slowFleet ++ [ runner [ run 13, stint 3 ] ]
                    in
                    ( Strategy.pitCycleOf hypercar cars |> .cycle
                    , energyOf cars 18 |> Maybe.map ceilingOf
                    )
                        |> Expect.equal ( Just 14, Just 13 )
            ]
        , describe "a car's level"
            [ test "counts the laps it has run since it last stopped" <|
                \_ ->
                    energyOf (fleet ++ [ runner [ run 10, stint 3 ] ]) 15
                        |> Maybe.map lapsLeft
                        |> Expect.equal (Just 7)
            , test "spends nothing on a lap the field was held down for" <|
                \_ ->
                    -- Three laps at pace and two under a procedure: five laps of
                    -- ground, three laps of energy.
                    energyOf (fleet ++ [ runner [ run 10, held 3 2 ] ]) 15
                        |> Maybe.map lapsLeft
                        |> Expect.equal (Just 7)
            , test "starts again at one on the stint after a stop" <|
                \_ ->
                    -- Two full stints behind it and three laps of the third: the
                    -- reading is of the energy the car is on, and no history of twenty
                    -- laps is in it.
                    energyOf (fleet ++ [ runner [ run 10, run 10, stint 3 ] ]) 27
                        |> Maybe.map lapsLeft
                        |> Expect.equal (Just 7)
            , test "reads past its plan as an overrun, in laps past" <|
                \_ ->
                    -- Thirteen laps run on its energy since its last stop, in a class
                    -- that comes in on 10: short-fuelling, which is a different telling
                    -- from a car on the ninth lap of the same plan.
                    energyOf (fleet ++ [ runner [ run 10, stint 13 ] ]) 25
                        |> Expect.equal
                            (Just
                                (Overrun
                                    { laps = 3
                                    , plan = 10
                                    , band = 0
                                    , ceiling = 10
                                    , fraction = 0
                                    }
                                )
                            )
            , test "and says how far the class got when it went further than that" <|
                \_ ->
                    -- The class on the ten-lap plan with a thirteen-lap ceiling: a car on its thirteenth lap is three past the plan, and the class's own longest run was thirteen, so the reading says the class itself never did better.
                    energyOf (slowFleet ++ [ runner [ run 13, stint 13 ] ]) 30
                        |> Expect.equal
                            (Just
                                (Overrun
                                    { laps = 3
                                    , plan = 10
                                    , band = 0
                                    , ceiling = 13
                                    , fraction = 0
                                    }
                                )
                            )
            , test "is full while every lap it has run was run under a procedure" <|
                \_ ->
                    -- Its class has a plan, and it has one lap under a procedure and nothing else.
                    -- The meter's unit excludes a held lap on both sides of the division, so none of the plan it stands on is spent: a car that has yet to run a lap at pace is drawn full, and not as a second kind of silence.
                    energyOf (fleet ++ [ runner [ held 0 1 ] ]) 11
                        |> Expect.equal (Just (Running { laps = 10, plan = 10, band = 0, ceiling = 10, fraction = 1 }))
            , test "and no level at all for a car the field does not hold" <|
                \_ ->
                    fleet
                        |> Energy.tableOf
                        |> Energy.level "99" 13
                        |> Expect.equal Nothing
            , test "is a share of the plan, which is what a bar is drawn at" <|
                \_ ->
                    energyOf (fleet ++ [ runner [ run 10, stint 3 ] ]) 15
                        |> Maybe.map fractionOf
                        |> Maybe.withDefault -1
                        |> Expect.within (Expect.Absolute 0.0001) 0.7
            ]
        ]



-- FIXTURES


{-| One of a car's runs: laps driven at pace, laps the field was held down for, and
whether a stop closed it.
-}
type alias RunSpec =
    { pace : Int
    , held : Int
    , stop : Bool
    }


run : Int -> RunSpec
run pace =
    { pace = pace, held = 0, stop = True }


stint : Int -> RunSpec
stint pace =
    { pace = pace, held = 0, stop = False }


held : Int -> Int -> RunSpec
held pace heldLaps =
    { pace = pace, held = heldLaps, stop = False }


{-| A run that met a procedure and stopped anyway, which is the kind that joins no
pool.
-}
heldRun : Int -> Int -> RunSpec
heldRun pace heldLaps =
    { pace = pace, held = heldLaps, stop = True }


{-| The class's reading pool: ten cars that each ran 10 laps and stopped.
-}
fleet : List Car
fleet =
    fleetOf 10 10


{-| Cars whose 40-lap runs met a procedure: long, and no reading of how far the
energy goes.
-}
heldFleet : List Car
heldFleet =
    heldFleetFrom 51 9


heldFleetFrom : Int -> Int -> List Car
heldFleetFrom first count =
    List.range first (first + count - 1)
        |> List.map (\n -> car (String.fromInt n) [ heldRun 40 1 ])


{-| Nine cars that ran 10 laps and two that ran 13.
-}
slowFleet : List Car
slowFleet =
    fleetOf 9 10 ++ [ car "41" [ run 13 ], car "42" [ run 13 ] ]


{-| Cars that each ran their own number of laps and stopped, numbered from two so the
car the tests read stays number one.
-}
fleetRunning : List Int -> List Car
fleetRunning paces =
    paces
        |> List.indexedMap (\i pace -> car (String.fromInt (i + 2)) [ run pace ])


{-| The car the tests read: it runs a stint of its own, which is what puts a lap at
pace behind the clock the test asks about.
-}
runner : List RunSpec -> Car
runner =
    car "1"


fleetOf : Int -> Int -> List Car
fleetOf count pace =
    fleetFrom 1 count pace


fleetFrom : Int -> Int -> Int -> List Car
fleetFrom first count pace =
    List.range first (first + count - 1)
        |> List.map (\n -> car (String.fromInt n) [ run pace ])


car : String -> List RunSpec -> Car
car number runs =
    { metadata =
        { carNumber = number
        , drivers = []
        , class = hypercar
        , group = "H"
        , team = "Team " ++ number
        , manufacturer = Manufacturer.unknown
        , imageUrl = Nothing
        }
    , startPosition = 1
    , laps = List.foldl (\spec laps -> laps ++ lapsOf (List.length laps + 1) spec) [] runs
    }


{-| A run: its laps at pace, its held laps, and the two laps a stop is written as --
the lap in, and the lap out with its lane time.
-}
lapsOf : Int -> RunSpec -> List Lap
lapsOf first spec =
    let
        paced =
            List.repeat spec.pace 0
                |> List.indexedMap (\i _ -> paceLap (first + i))

        heldLaps =
            List.repeat spec.held 0
                |> List.indexedMap (\i _ -> heldLap (first + spec.pace + i))

        closing =
            if spec.stop then
                [ inLap (first + spec.pace + spec.held)
                , outLap (first + spec.pace + spec.held + 1)
                ]

            else
                []
    in
    paced ++ heldLaps ++ closing


paceLap : Int -> Lap
paceLap number =
    lapAt Lap.Green number Lap.NoCrossing


heldLap : Int -> Lap
heldLap number =
    lapAt Lap.SlowZone number Lap.NoCrossing


inLap : Int -> Lap
inLap number =
    lapAt Lap.Green number Lap.EntryAtEnd


outLap : Int -> Lap
outLap number =
    lapAt Lap.Green number (Lap.ExitAtStart 70000)


lapAt : Lap.Flag -> Int -> Lap.Crossing -> Lap
lapAt flag number crossing =
    let
        empty =
            Lap.empty
    in
    { empty
        | carNumber = "0"
        , lap = number
        , time = Just 100000
        , crossing = crossing
        , flag = flag
    }



-- READINGS


energyOf : List Car -> Int -> Maybe Energy
energyOf cars clock =
    cars |> Energy.tableOf |> Energy.level "1" clock


planOf : Energy -> Int
planOf reading =
    case reading of
        Running level ->
            level.plan

        Overrun level ->
            level.plan

        Spread _ ->
            -1

        Unreadable ->
            -1


ceilingOf : Energy -> Int
ceilingOf reading =
    case reading of
        Running level ->
            level.ceiling

        Overrun level ->
            level.ceiling

        Spread _ ->
            -1

        Unreadable ->
            -1


bandOf : Energy -> Int
bandOf reading =
    case reading of
        Running level ->
            level.band

        Overrun level ->
            level.band

        Spread _ ->
            -1

        Unreadable ->
            -1


lapsLeft : Energy -> Int
lapsLeft reading =
    case reading of
        Running level ->
            level.laps

        Overrun level ->
            -level.laps

        Spread _ ->
            -1

        Unreadable ->
            -1


{-| The laps a class's quarters, its middle stop and its longest run fell on. A level answers none of that.
-}
spreadOf : Energy -> Energy.Stops
spreadOf reading =
    case reading of
        Spread stops ->
            stops

        _ ->
            { low = -1, high = -1, median = -1, ceiling = -1 }


fractionOf : Energy -> Float
fractionOf reading =
    case reading of
        Running level ->
            level.fraction

        _ ->
            -1


hypercar : Class
hypercar =
    Class.fromString Era.Gt3AsThirdClass "HYPERCAR"
