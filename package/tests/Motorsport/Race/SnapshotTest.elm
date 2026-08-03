module Motorsport.Race.SnapshotTest exposing (suite)

import Expect
import Motorsport.BestTimes as BestTimes
import Motorsport.Class as Class exposing (Class)
import Motorsport.Class.Era as Era
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance exposing (PerformanceLevel(..))
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race as Race
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Sector as Sector exposing (Sector(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.Race.Snapshot"
        [ describe "the field is put in the order it is running in"
            [ test "the car further into the race leads, whatever order the entry list came in" <|
                \_ ->
                    snapshotAt 7000
                        |> Snapshot.toList
                        |> List.map (\car -> ( car.position, car.metadata.carNumber ))
                        |> Expect.equal [ ( 1, "2" ), ( 2, "1" ) ]
            , test "the leader is the car in first" <|
                \_ ->
                    snapshotAt 7000
                        |> Snapshot.leader
                        |> Maybe.map (.metadata >> .carNumber)
                        |> Expect.equal (Just "2")
            , test "the leader is not behind itself, so it reports no gap" <|
                \_ ->
                    snapshotAt 7000
                        |> Snapshot.toList
                        |> List.map (.gapToLeader >> Gap.toString)
                        |> List.head
                        |> Expect.equal (Just "-")
            , test "the car behind reports one" <|
                \_ ->
                    snapshotAt 7000
                        |> carAt "1"
                        |> Maybe.map (.gapToLeader >> Gap.toString)
                        |> Expect.notEqual (Just "-")
            ]
        , describe "each car is placed within its class as well as within the field"
            [ test "a class of one puts its car first, whatever it stands overall" <|
                \_ ->
                    snapshotAt 7000
                        |> Snapshot.toList
                        |> List.map (\car -> ( car.metadata.carNumber, car.positionInClass ))
                        |> Expect.equal [ ( "2", 1 ), ( "1", 1 ) ]
            , test "the classes come out grouped, the leader's first" <|
                \_ ->
                    snapshotAt 7000
                        |> Snapshot.toClassList
                        |> List.map (Tuple.second >> List.map (.metadata >> .carNumber))
                        |> Expect.equal [ [ "2" ], [ "1" ] ]
            ]
        , describe "the sectors of the lap a car is on"
            [ test "are complete behind it and untouched ahead of it" <|
                \_ ->
                    -- Car 1 started its second lap at 6.000 and the clock says
                    -- 7.000: a second in, which is all of S1 and none of S2.
                    sectorStatesOf "1" (snapshotAt 7000)
                        |> Maybe.map (Sector.toList >> List.map (\( sector, state ) -> ( sector, state.progress )))
                        |> Expect.equal (Just [ ( S1, 1 ), ( S2, 0 ), ( S3, 0 ) ])
            , test "are rated against the record as it stood at that moment" <|
                \_ ->
                    -- Of the laps run by 7.000, car 1's S1 of 1.000 is the
                    -- quickest anyone has gone through S1.
                    sectorStatesOf "1" (snapshotAt 7000)
                        |> Maybe.map (Sector.toList >> List.map (\( sector, state ) -> ( sector, Maybe.map .performance state.rated )))
                        |> Expect.equal
                            (Just [ ( S1, Just Fastest ), ( S2, Just Standard ), ( S3, Just Standard ) ])
            ]
        , describe "the records come from the same clock as the rest"
            [ test "stand at the quickest of the laps run by then" <|
                \_ ->
                    snapshotAt 7000
                        |> Snapshot.bestTimes
                        |> (.fastestLapTime >> BestTimes.timeOf)
                        |> Expect.equal (Just 5000)
            , test "know nothing of a lap the clock has not reached" <|
                \_ ->
                    -- Car 2's second lap, a 4.000, ends at 9.000.
                    snapshotAt 9000
                        |> Snapshot.bestTimes
                        |> (.fastestLapTime >> BestTimes.timeOf)
                        |> Expect.equal (Just 4000)
            ]
        ]



-- FIXTURE
--
-- Two cars, one in each of two classes, so class position and overall position
-- cannot be confused for one another. Car 2 completes laps at 5.000 and 9.000,
-- car 1 at 6.000 and 12.000, which puts car 2 ahead throughout.


snapshotAt : Duration -> Snapshot
snapshotAt elapsed =
    Race.fromCars [ carOne, carTwo ]
        |> Snapshot.at { elapsed = Instant.fromDuration elapsed }


carAt : String -> Snapshot -> Maybe CarAt
carAt carNumber snapshot =
    Snapshot.toList snapshot
        |> List.filter (\car -> car.metadata.carNumber == carNumber)
        |> List.head


sectorStatesOf : String -> Snapshot -> Maybe Snapshot.CurrentSectorStates
sectorStatesOf carNumber snapshot =
    carAt carNumber snapshot
        |> Maybe.andThen .currentLapSectorStates


carOne : Car
carOne =
    { metadata = metadataOf "1" (classOf "HYPERCAR")
    , startPosition = 1
    , laps =
        [ lapOf "1" 1 6000 6000 { s1 = 1000, s2 = 2000, s3 = 3000 }
        , lapOf "1" 2 6000 12000 { s1 = 1000, s2 = 2000, s3 = 3000 }
        ]
    }


carTwo : Car
carTwo =
    { metadata = metadataOf "2" (classOf "LMGT3")
    , startPosition = 2
    , laps =
        [ lapOf "2" 1 5000 5000 { s1 = 1500, s2 = 1500, s3 = 2000 }
        , lapOf "2" 2 4000 9000 { s1 = 1500, s2 = 1500, s3 = 1000 }
        ]
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
    , manufacturer = Manufacturer.Other
    }


{-| Sector times with no personal best against them, so a sector reads as
`Fastest` or as `Standard` and never as a personal best -- which is what keeps
the rating test about the race's record rather than the driver's own.
-}
lapOf : String -> Int -> Duration -> Duration -> { s1 : Duration, s2 : Duration, s3 : Duration } -> Lap
lapOf carNumber lapNumber time elapsed sectors =
    { empty
        | carNumber = carNumber
        , driver = Driver.fromName ("Driver " ++ carNumber)
        , lap = lapNumber
        , position = Just 1
        , time = Just time
        , elapsed = Instant.fromDuration elapsed
        , sectors =
            Sector.initialize
                (\sector ->
                    { time =
                        Just <|
                            case sector of
                                S1 ->
                                    sectors.s1

                                S2 ->
                                    sectors.s2

                                S3 ->
                                    sectors.s3
                    , personalBest = Nothing
                    }
                )
    }


empty : Lap
empty =
    Lap.empty
