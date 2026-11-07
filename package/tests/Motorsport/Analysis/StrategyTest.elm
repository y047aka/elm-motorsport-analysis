module Motorsport.Analysis.StrategyTest exposing (suite)

import Expect
import Motorsport.Analysis.Stint as Stint
import Motorsport.Analysis.Strategy as Strategy
import Motorsport.Driver as Driver
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Stint exposing (Stint)
import Motorsport.Status as Status
import Motorsport.Wec.Class as Class exposing (Class)
import Motorsport.Wec.Era as Era
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Analysis.Strategy"
        [ describe "pitCycleOf"
            [ test "the distance is how far the class came, and says nothing of other classes" <|
                \_ ->
                    Strategy.pitCycleOf (classOf "HYPERCAR") [ stoppedTwice, stoppedOnce, longGt3 ]
                        |> .distance
                        |> Expect.equal 12
            , test "the cycle is the ninetieth percentile of the clean stopped runs" <|
                \_ ->
                    -- Ten runs of 6 and two of 5: the window sits at the top
                    -- of that, not its middle.
                    Strategy.pitCycleOf (classOf "HYPERCAR") (stoppedTwice :: fleetOf 10)
                        |> .cycle
                        |> Expect.equal (Just 6)
            , test "a run the field was held down for is no reading of a tank" <|
                \_ ->
                    -- The held car reached 9 on its tank, but four of those
                    -- laps were under a procedure. Nine clean runs and one
                    -- held one do not make a pool of ten: the class answers
                    -- nothing rather than answering from the held run.
                    Strategy.pitCycleOf (classOf "HYPERCAR") (heldLong :: fleetOf 9)
                        |> .cycle
                        |> Expect.equal Nothing
            , test "a handful of runs is one fuel run wearing the class's name" <|
                \_ ->
                    Strategy.pitCycleOf (classOf "HYPERCAR") (fleetOf 3)
                        |> .cycle
                        |> Expect.equal Nothing
            , test "no cycle before the class has stopped" <|
                \_ ->
                    Strategy.pitCycleOf (classOf "HYPERCAR") [ neverStopped ]
                        |> .cycle
                        |> Expect.equal Nothing
            ]
        , describe "plan"
            [ test "the cycle repeats to the end of the race, the first run the laps left of the one going" <|
                \_ ->
                    -- Five on the clock: a stop due in the 1 lap left of the run
                    -- this car is on, then one whole run to the flag at 20.
                    plannedOn (onClock 20 5) 14 [ 5, 10 ] 14
                        |> Expect.equal
                            [ { laps = 1, stop = 15 }
                            , { laps = 5, stop = 20 }
                            ]
            , test "a past its length, the cycle counts from where the car stands" <|
                \_ ->
                    -- Seven laps out and no stop yet: the next whole run of five
                    -- is all that stands, cut to the two laps of its own race left.
                    plannedOn (onClock 20 5) 17 [ 5, 10 ] 17
                        |> Expect.equal [ { laps = 3, stop = 20 } ]
            , test "a car four laps down has four laps less of race to forecast" <|
                \_ ->
                    plannedOn (onClock 20 5) 16 [ 5, 10 ] 12
                        |> Expect.equal
                            [ { laps = 3, stop = 15 }
                            , { laps = 1, stop = 16 }
                            ]
            , test "a car in the lane is forecast from back out onto the track" <|
                \_ ->
                    -- Twelve run, in the lane at the head of the race: the
                    -- forecast counts the next window from the line the car
                    -- will cross back out on.
                    plannedOn (onClock 30 5) 12 [ 5, 10 ] 12
                        |> List.map .stop
                        |> Expect.equal [ 15, 20, 25, 30 ]
            , test "the whole race left, nothing is forecast" <|
                \_ ->
                    plannedOn (onClock 20 5) 20 [ 5, 10, 15, 20 ] 20
                        |> Expect.equal []
            , test "the plan's laps sum to the race the car has left" <|
                \_ ->
                    -- Four laps of race left for a car four down at 12 of 20;
                    -- the plan holds four laps, no more and no less.
                    plannedOn (onClock 20 5) 16 [ 5, 10 ] 12
                        |> sumByLaps
                        |> Expect.equal (20 - (16 - 12) - 12)
            , test "no cycle, no forecast" <|
                \_ ->
                    plannedOn { distance = 20, cycle = Nothing } 20 [] 14
                        |> Expect.equal []
            , test "a window of no laps cannot be repeated forever" <|
                \_ ->
                    plannedOn (onClock 20 0) 20 [ 5 ] 5
                        |> Expect.equal []
            , test "a car that has stopped for good has no stops to forecast" <|
                \_ ->
                    -- Retired and flag-finished both: mid-race and on the
                    -- leader's distance, neither has a future stop.
                    Expect.equal
                        ( plannedOnWhen Status.Retired (onClock 20 5) 20 [ 5 ] 10
                            , plannedOnWhen Status.Checkered (onClock 20 5) 20 [ 5, 10, 15 ] 15
                        )
                    <|
                        ( [], [] )
            , test "a class with no cars has neither distance nor cycle" <|
                \_ ->
                    Expect.equal
                        (Strategy.pitCycleOf (classOf "HYPERCAR") [])
                        { distance = 0, cycle = Nothing }
            ]
        ]


onClock : Int -> Int -> Strategy.PitCycle
onClock distance cycleLength =
    { distance = distance
    , cycle = Just cycleLength
    }


stints : List Int -> Int -> List Stint
stints stops lapCount =
    summary stops lapCount |> .stints


summary : List Int -> Int -> Stint.Summary
summary stops lapCount =
    lapsOf stops lapCount |> Stint.summarize


plannedOn : Strategy.PitCycle -> Int -> List Int -> Int -> List Strategy.PredictedStint
plannedOn cycle lead stops lapCount =
    plannedOnWhen Status.Racing cycle lead stops lapCount


plannedOnWhen : Status.Status -> Strategy.PitCycle -> Int -> List Int -> Int -> List Strategy.PredictedStint
plannedOnWhen status cycle lead stops lapCount =
    Strategy.plan cycle lead status (summary stops lapCount)
        |> .planned


stoppedTwice : Car
stoppedTwice =
    carOf "1" "HYPERCAR" [ 5, 10 ] 12


stoppedOnce : Car
stoppedOnce =
    carOf "3" "HYPERCAR" [ 6 ] 12


heldLong : Car
heldLong =
    carHeld "9" "HYPERCAR" [ 9 ] [ 5, 6, 7, 8 ] 12


{-| `n` cars of the class, each stopping once at 6 on a 12-lap race: a pool of
`n` clean runs of 6.
-}
fleetOf : Int -> List Car
fleetOf n =
    List.map (\i -> carOf (String.fromInt (100 + i)) "HYPERCAR" [ 6 ] 12) (List.range 1 n)


neverStopped : Car
neverStopped =
    carOf "7" "HYPERCAR" [] 12


longGt3 : Car
longGt3 =
    carOf "81" "LMGT3" [ 8, 16, 24 ] 30


carOf : String -> String -> List Int -> Int -> Car
carOf carNumber class stops lapCount =
    carAt carNumber class stops [] lapCount


carHeld : String -> String -> List Int -> List Int -> Int -> Car
carHeld carNumber class stops held lapCount =
    carAt carNumber class stops held lapCount


carAt : String -> String -> List Int -> List Int -> Int -> Car
carAt carNumber class stops held lapCount =
    { metadata =
        { carNumber = carNumber
        , drivers = [ Driver.fromName ("Driver " ++ carNumber) ]
        , class = classOf class
        , group = "H"
        , team = "Team " ++ carNumber
        , manufacturer = Manufacturer.unknown
        , imageUrl = Nothing
        }
    , startPosition = 1
    , laps = lapsOfWith stops held lapCount
    }


{-| A race of `lapCount` laps with a stop on each of `stops` -- entry and exit
the pair `Race.Stint` reads a stop as -- and a procedure over each of `held`.
-}
lapsOfWith : List Int -> List Int -> Int -> List Lap
lapsOfWith stops held lapCount =
    List.range 1 lapCount
        |> List.map
            (\lapNumber ->
                { emptyLap
                    | carNumber = "0"
                    , driver = Driver.fromName "Driver"
                    , lap = lapNumber
                    , time = Just 5000
                    , flag =
                        if List.member lapNumber held then
                            Lap.SlowZone

                        else
                            Lap.Green
                    , crossing =
                        if List.member lapNumber stops then
                            Lap.EntryAtEnd

                        else if List.member (lapNumber - 1) stops then
                            Lap.ExitAtStart 30000

                        else
                            Lap.NoCrossing
                }
            )


lapsOf : List Int -> Int -> List Lap
lapsOf stops =
    lapsOfWith stops []


sumByLaps : List Strategy.PredictedStint -> Int
sumByLaps =
    List.sum << List.map .laps


emptyLap : Lap
emptyLap =
    Lap.empty


classOf : String -> Class
classOf =
    Class.fromString Era.Gt3AsThirdClass
