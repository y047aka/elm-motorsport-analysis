module Motorsport.Analysis.StrategyTest exposing (suite)

import Expect
import Motorsport.Analysis.Strategy as Strategy
import Motorsport.Driver as Driver
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race.Car exposing (Car)
import Motorsport.Wec.Class as Class exposing (Class)
import Motorsport.Wec.Era as Era
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Analysis.Strategy"
        [ describe "ofRace"
            [ test "the distance is how far the class came, and says nothing of other classes" <|
                \_ ->
                    Strategy.ofRace (classOf "HYPERCAR") 12 [ stoppedTwice, stoppedOnce, longGt3 ]
                        |> .distance
                        |> Expect.equal 12
            , test "the spacing is the mode of the runs a stop ended" <|
                \_ ->
                    -- Runs of 5 and 5 from one car, 6 from another, and the
                    -- flag-cut tails of neither: five is what this race stopped on.
                    Strategy.ofRace (classOf "HYPERCAR") 12 [ stoppedTwice, stoppedOnce, longGt3 ]
                        |> .spacing
                        |> Expect.equal (Just 5)
            , test "no spacing before the class has stopped" <|
                \_ ->
                    Strategy.ofRace (classOf "HYPERCAR") 12 [ neverStopped ]
                        |> .spacing
                        |> Expect.equal Nothing
            ]
        , describe "horizon"
            [ test "the leader has the whole race left of the leader's distance" <|
                \_ ->
                    Strategy.horizon race 100
                        |> Expect.equal 100
            , test "a car five laps down has five laps less of race" <|
                \_ ->
                    Strategy.horizon race 95
                        |> Expect.equal 95
            ]
        ]


race : Strategy.Strategy
race =
    { distance = 100
    , spacing = Just 14
    , lead = 100
    }


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
    , laps =
        List.range 1 lapCount
            |> List.map
                (\lapNumber ->
                    { emptyLap
                        | carNumber = carNumber
                        , driver = Driver.fromName ("Driver " ++ carNumber)
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
    }


emptyLap : Lap
emptyLap =
    Lap.empty


classOf : String -> Class
classOf =
    Class.fromString Era.Gt3AsThirdClass
