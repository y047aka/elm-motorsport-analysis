module Motorsport.Analysis.ClassPositionsTest exposing (suite)

import Expect
import Motorsport.Analysis.ClassPositions as ClassPositions
import Motorsport.Analysis.LapWindow exposing (Laps)
import Motorsport.BestTimes as BestTimes
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Internal.ChangePoints as ChangePoints
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race as Race
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Wec.Class as Class exposing (Class)
import Motorsport.Wec.Era as Era
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Analysis.ClassPositions"
        [ describe "who answers"
            [ test "the cars of the class, and only those" <|
                \_ ->
                    ClassPositions.byCar wholeRace (classOf "HYPERCAR") field
                        |> List.map (Tuple.first >> .metadata >> .carNumber)
                        |> List.sort
                        |> Expect.equal [ "1", "3" ]
            , test "a class no car races in has no one to answer for it" <|
                \_ ->
                    ClassPositions.byCar wholeRace (classOf "LMP2") field
                        |> Expect.equal []
            , test "a car with nothing inside the window answers with nothing, rather than dropping out" <|
                \_ ->
                    ClassPositions.byCar { first = 10, last = 12 } (classOf "HYPERCAR") field
                        |> List.map Tuple.second
                        |> Expect.equal [ [], [] ]
            ]
        , describe "the places a car held"
            [ test "one per lap it was given a position on" <|
                \_ ->
                    -- Car 1 was second by the end, and lap 3 went unrecorded.
                    pointsFor "1" wholeRace
                        |> Expect.equal
                            [ { lap = 1, position = 1 }
                            , { lap = 2, position = 1 }
                            , { lap = 4, position = 2 }
                            ]
            , test "the window keeps only the laps inside it" <|
                \_ ->
                    pointsFor "3" { first = 2, last = 3 }
                        |> Expect.equal
                            [ { lap = 2, position = 2 }
                            , { lap = 3, position = 1 }
                            ]
            ]
        ]



-- FIXTURE
--
-- Two Hypercars swapping places over four laps, and a GT3 car that shares
-- neither the class nor the places. Car 1's third lap has no position against
-- it, which is what a lap the feed did not record reads as.


wholeRace : Laps
wholeRace =
    { first = 1, last = 4 }


pointsFor : String -> Laps -> List ClassPositions.Point
pointsFor carNumber window =
    ClassPositions.byCar window (classOf "HYPERCAR") field
        |> List.filter (\( car, _ ) -> car.metadata.carNumber == carNumber)
        |> List.concatMap Tuple.second


field : Snapshot
field =
    Race.fromCars { timeLimit = Instant.raceStart, index = noIndex } [ leader, chaser, otherClass ]
        |> Snapshot.at { elapsed = Instant.fromDuration 30000 }


leader : Car
leader =
    carOf "1" "HYPERCAR" [ ( 5000, Just 1 ), ( 10000, Just 1 ), ( 15000, Nothing ), ( 20000, Just 2 ) ]


chaser : Car
chaser =
    carOf "3" "HYPERCAR" [ ( 6000, Just 2 ), ( 12000, Just 2 ), ( 18000, Just 1 ), ( 24000, Just 1 ) ]


otherClass : Car
otherClass =
    carOf "2" "LMGT3" [ ( 7000, Just 1 ), ( 14000, Just 1 ) ]


{-| A car whose laps end at the given moments and stand where they say,
numbered from one.
-}
carOf : String -> String -> List ( Duration, Maybe Int ) -> Car
carOf carNumber class completions =
    { metadata = metadataOf carNumber (classOf class)
    , startPosition = 1
    , laps =
        completions
            |> List.indexedMap (\i ( elapsed, position ) -> lapOf carNumber (i + 1) elapsed position)
    }


lapOf : String -> Int -> Duration -> Maybe Int -> Lap
lapOf carNumber lapNumber elapsed position =
    { emptyLap
        | carNumber = carNumber
        , driver = Driver.fromName ("Driver " ++ carNumber)
        , lap = lapNumber
        , position = position
        , time = Just 5000
        , elapsed = Instant.fromDuration elapsed
    }


emptyLap : Lap
emptyLap =
    Lap.empty


{-| The records a round arrives with, which nothing here reads.
-}
noIndex : Race.Index
noIndex =
    { lapCompletions = ChangePoints.empty
    , bestTimeChanges = BestTimes.empty
    }


classOf : String -> Class
classOf =
    Class.fromString Era.Gt3AsThirdClass


metadataOf : String -> Class -> Car.Metadata
metadataOf carNumber class =
    { carNumber = carNumber
    , drivers = [ Driver.fromName ("Driver " ++ carNumber) ]
    , class = class
    , group = "H"
    , team = "Team " ++ carNumber
    , manufacturer = Manufacturer.unknown
    , imageUrl = Nothing
    }
