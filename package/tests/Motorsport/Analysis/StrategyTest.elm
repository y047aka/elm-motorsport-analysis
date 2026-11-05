module Motorsport.Analysis.StrategyTest exposing (suite)

import Expect
import Motorsport.Analysis.Stint as Stint
import Motorsport.Analysis.Strategy as Strategy
import Motorsport.Driver as Driver
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Stint exposing (Stint)
import Motorsport.Wec.Class as Class exposing (Class)
import Motorsport.Wec.Era as Era
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Analysis.Strategy"
        [ describe "pitCycleOf"
            [ test "the distance is how far the class came, and says nothing of other classes" <|
                \_ ->
                    Strategy.pitCycleOf (classOf "HYPERCAR") 12 [ stoppedTwice, stoppedOnce, longGt3 ]
                        |> .distance
                        |> Expect.equal 12
            , test "the cycle length is the mode of the runs a stop ended" <|
                \_ ->
                    -- Runs of 5 and 5 from one car, 6 from another, and the
                    -- flag-cut tails of neither: five is what this race stopped on.
                    Strategy.pitCycleOf (classOf "HYPERCAR") 12 [ stoppedTwice, stoppedOnce, longGt3 ]
                        |> .cycle
                        |> Expect.equal (Just 5)
            , test "no cycle length before the class has stopped" <|
                \_ ->
                    Strategy.pitCycleOf (classOf "HYPERCAR") 12 [ neverStopped ]
                        |> .cycle
                        |> Expect.equal Nothing
            ]
        , describe "forecast"
            [ test "the cycle repeats to the end of the race, the first run the laps left of the one going" <|
                \_ ->
                    -- Five on the clock: a stop due in the 1 lap left of the run
                    -- this car is on, then one whole run to the flag at 20.
                    Strategy.forecast (onClock 20 5 14) (stints [ 5, 10 ] 14)
                        |> Expect.equal
                            [ { laps = 1, stop = 15 }
                            , { laps = 5, stop = 20 }
                            ]
            , test "a past its length, the cycle counts from where the car stands" <|
                \_ ->
                    -- Seven laps out and no stop yet: the next whole run of five
                    -- is all that stands, cut to the two laps of its own race left.
                    Strategy.forecast (onClock 20 5 17) (stints [ 5, 10 ] 17)
                        |> Expect.equal [ { laps = 3, stop = 20 } ]
            , test "a car five laps down has five laps less of race to forecast" <|
                \_ ->
                    Strategy.forecast (onClock 20 5 16) (stints [ 5, 10 ] 12)
                        |> Expect.equal
                            [ { laps = 3, stop = 15 }
                            , { laps = 1, stop = 16 }
                            ]
            , test "the whole race left, nothing is forecast" <|
                \_ ->
                    Strategy.forecast (onClock 20 5 20) (stints [ 5, 10, 15, 20 ] 20)
                        |> Expect.equal []
            , test "the plan's laps sum to the race the car has left" <|
                \_ ->
                    -- Four laps of race left for a car four down at 12 of 20;
                    -- the plan holds four laps, no more and no less.
                    Strategy.forecast (onClock 20 5 16) (stints [ 5, 10 ] 12)
                        |> sumByLaps
                        |> Expect.equal (20 - (16 - 12) - 12)
            , test "no cycle length, no forecast" <|
                \_ ->
                    Strategy.forecast { distance = 20, cycle = Nothing, lead = 20 } (stints [] 14)
                        |> Expect.equal []
            ]
        ]


onClock : Int -> Int -> Int -> Strategy.PitCycle
onClock distance cycleLength lead =
    { distance = distance
    , cycle = Just cycleLength
    , lead = lead
    }


stints : List Int -> Int -> List Stint
stints stops lapCount =
    lapsOf stops lapCount |> Stint.summarize |> .stints


stoppedTwice : Car
stoppedTwice =
    carOf "1" "HYPERCAR" [ 5, 10 ] 12


stoppedOnce : Car
stoppedOnce =
    carOf "3" "HYPERCAR" [ 6 ] 12


neverStopped : Car
neverStopped =
    carOf "7" "HYPERCAR" [] 12


longGt3 : Car
longGt3 =
    carOf "81" "LMGT3" [ 8, 16, 24 ] 30


carOf : String -> String -> List Int -> Int -> Car
carOf carNumber class stops lapCount =
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
    , laps = lapsOf stops lapCount
    }


{-| A race of `lapCount` laps with a stop on each of `stops` -- entry and exit
the pair `Race.Stint` reads a stop as.
-}
lapsOf : List Int -> Int -> List Lap
lapsOf stops lapCount =
    List.range 1 lapCount
        |> List.map
            (\lapNumber ->
                { emptyLap
                    | carNumber = "0"
                    , driver = Driver.fromName "Driver"
                    , lap = lapNumber
                    , time = Just 5000
                    , crossing =
                        if List.member lapNumber stops then
                            Lap.EntryAtEnd

                        else if List.member (lapNumber - 1) stops then
                            Lap.ExitAtStart 30000

                        else
                            Lap.NoCrossing
                }
            )


sumByLaps : Strategy.Strategy -> Int
sumByLaps =
    List.sum << List.map .laps


emptyLap : Lap
emptyLap =
    Lap.empty


classOf : String -> Class
classOf =
    Class.fromString Era.Gt3AsThirdClass
