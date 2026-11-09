module Motorsport.Analysis.TankTest exposing (suite)

import Expect
import Motorsport.Analysis.Strategy as Strategy
import Motorsport.Analysis.Tank as Tank exposing (Tank(..))
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race.Car exposing (Car)
import Motorsport.Wec.Class as Class exposing (Class)
import Motorsport.Wec.Era as Era
import Test exposing (Test, describe, test)


{-| The fixtures are built so the window comes out of a whole number of laps and the
reading is a subtraction a test can do in its head: wherever a test says nothing to
the contrary the class's window is 10 laps, and the car being read has run a first
stint of 10 and stopped, which is the eleventh clean run the pool is read from.

The clock asks one question -- where the car stands on the tank it is on -- and never the window: a class's window is the finished race's, so a test may ask about any lap it likes and read the subtraction off the same ten laps.
-}
suite : Test
suite =
    describe "Motorsport.Analysis.Tank"
        [ describe "the class's window"
            [ test "is the top of its stopped runs, not their middle" <|
                \_ ->
                    -- Nine cars ran 10 laps and two ran 13, the reading car's own
                    -- first stint a thirteenth: the decile is 13, and a meter that
                    -- read the middle of that class would say 10 and call every
                    -- 13-lap run an overrun.
                    tankOf (slowFleet ++ [ runner [ run 13, stint 3 ] ]) 18
                        |> Maybe.map windowOf
                        |> Expect.equal (Just 13)
            , test "and no window while the class has fewer than ten clean stopped runs" <|
                \_ ->
                    -- Eight cars and the reading car's own first stint: nine clean
                    -- runs, one short of a decile that means anything.
                    tankOf (fleetOf 8 10 ++ [ runner [ run 10, stint 3 ] ]) 15
                        |> Expect.equal (Just (Unreadable Tank.NoWindow))
            , test "is not read from a run the field was held down for" <|
                \_ ->
                    -- Ten clean runs of 10, and nine of 40 that met a procedure on
                    -- the way, all of them in the past by the lap asked about: the
                    -- long runs are what a caution is worth, not what a tank is
                    -- worth, so the window stays 10.
                    tankOf (fleet ++ heldFleet ++ [ runner [ run 10, stint 33 ] ]) 45
                        |> Maybe.map windowOf
                        |> Expect.equal (Just 10)
            , test "is the same window at the first lap as at the flag" <|
                \_ ->
                    -- The class's word is the whole race's, which is what lets a
                    -- column of cars be drawn from one reading of it; the clock moves
                    -- the car along its tank and never moves the tank.
                    let
                        cars =
                            fleet ++ [ runner [ run 10, stint 3 ] ]
                    in
                    ( tankOf cars 3 |> Maybe.map windowOf
                    , tankOf cars 15 |> Maybe.map windowOf
                    )
                        |> Expect.equal ( Just 10, Just 10 )
            , test "is read to a quarter of the window itself, and past it as the class's own stops" <|
                \_ ->
                    -- Four laps of disagreement out of a 16-lap window is the gate standing at exactly a quarter, and the first class is read as a level.
                    -- Five of the same 16 is past the gate, and the answer becomes the class's own stops: its quarters at 11 and 16, its middle stop on 11, drawn against its 16-lap window.
                    -- The last class is tri-modal at 10, 15 and 22 laps and disagrees by 12 of its own 22, which is a class of teams choosing when to stop rather than a class running on fuel.
                    let
                        quarter =
                            fleetFrom 2 9 12 ++ fleetFrom 21 4 16

                        past =
                            fleetFrom 2 8 11 ++ fleetFrom 21 5 16
                    in
                    ( tankOf (quarter ++ [ runner [ run 16 ] ]) 20 |> Maybe.map windowOf
                    , tankOf (past ++ [ runner [ run 16 ] ]) 20 |> Maybe.map spreadOf
                    , tankOf (wideFleet ++ [ runner [ run 22, stint 1 ] ]) 25 |> Maybe.map spreadOf
                    )
                        |> Expect.equal
                                ( Just 16, Just { low = 11, high = 16, median = 11, window = 16 }, Just { low = 10, high = 22, median = 15, window = 22 } )
            , test "stands within a lap of the cycle Strategy reads off the same stops" <|
                \_ ->
                    -- Strategy counts the lap into the pits and Tank does not, which
                    -- is the whole of the difference between the two, and no more.
                    let
                        cars =
                            slowFleet ++ [ runner [ run 13, stint 3 ] ]
                    in
                    ( Strategy.pitCycleOf hypercar cars |> .cycle
                    , tankOf cars 18 |> Maybe.map windowOf
                    )
                        |> Expect.equal ( Just 14, Just 13 )
            ]
        , describe "a car's level"
            [ test "counts the laps it has run since it last refuelled" <|
                \_ ->
                    tankOf (fleet ++ [ runner [ run 10, stint 3 ] ]) 15
                        |> Maybe.map lapsLeft
                        |> Expect.equal (Just 7)
            , test "burns nothing on a lap the field was held down for" <|
                \_ ->
                    -- Three laps at pace and two under a procedure: five laps of
                    -- ground, three laps of fuel.
                    tankOf (fleet ++ [ runner [ run 10, held 3 2 ] ]) 15
                        |> Maybe.map lapsLeft
                        |> Expect.equal (Just 7)
            , test "starts again at one on the stint after a stop" <|
                \_ ->
                    -- Two full stints behind it and three laps of the third: the
                    -- reading is of the tank the car is on, and no history of twenty
                    -- laps is in it.
                    tankOf (fleet ++ [ runner [ run 10, run 10, stint 3 ] ]) 27
                        |> Maybe.map lapsLeft
                        |> Expect.equal (Just 7)
            , test "reads past its window as an overrun, in laps past" <|
                \_ ->
                    -- Thirteen laps run on the tank since its last stop, in a class
                    -- that runs 10: short-fuelling, which is a different telling
                    -- from a car on the ninth lap of the same tank.
                    tankOf (fleet ++ [ runner [ run 10, stint 13 ] ]) 25
                        |> Expect.equal
                            (Just
                                (Overrun
                                    { laps = 3
                                    , window = 10
                                    , band = 0
                                    , fraction = 0
                                    }
                                )
                            )
            , test "has no level for a car that has yet to run a lap at pace" <|
                \_ ->
                    -- Its class has a window; it has one lap under a procedure and
                    -- nothing else, which is not a tank of ten laps.
                    tankOf (fleet ++ [ runner [ held 0 1 ] ]) 11
                        |> Expect.equal (Just (Unreadable Tank.NoRun))
            , test "and no level at all for a car the field does not hold" <|
                \_ ->
                    fleet
                        |> Tank.tableOf
                        |> Tank.level "99" 13
                        |> Expect.equal Nothing
            , test "is a share of the window, which is what a bar is drawn at" <|
                \_ ->
                    tankOf (fleet ++ [ runner [ run 10, stint 3 ] ]) 15
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


{-| Cars whose 40-lap runs met a procedure: long, and no reading of a tank.
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


{-| A class that disagrees with itself: four runs of 10, four of 15 and five of 22,
the reading car itself coming in on one of the 22.
-}
wideFleet : List Car
wideFleet =
    fleetFrom 2 4 10 ++ fleetFrom 21 4 15 ++ fleetFrom 31 5 22


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


tankOf : List Car -> Int -> Maybe Tank
tankOf cars clock =
    cars |> Tank.tableOf |> Tank.level "1" clock


windowOf : Tank -> Int
windowOf tank =
    case tank of
        Running level ->
            level.window

        Overrun level ->
            level.window

        Spread _ ->
            -1

        Unreadable _ ->
            -1


lapsLeft : Tank -> Int
lapsLeft tank =
    case tank of
        Running level ->
            level.laps

        Overrun level ->
            -level.laps

        Spread _ ->
            -1

        Unreadable _ ->
            -1


{-| The laps a class's quarters and its middle stop fell on, and the window the bar is drawn against. A level answers none of that.
-}
spreadOf : Tank -> Tank.Stops
spreadOf tank =
    case tank of
        Tank.Spread stops ->
            stops

        _ ->
            { low = -1, high = -1, median = -1, window = -1 }


fractionOf : Tank -> Float
fractionOf tank =
    case tank of
        Running level ->
            level.fraction

        _ ->
            -1


hypercar : Class
hypercar =
    Class.fromString Era.Gt3AsThirdClass "HYPERCAR"
