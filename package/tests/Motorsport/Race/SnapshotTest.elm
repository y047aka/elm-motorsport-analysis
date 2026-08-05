module Motorsport.Race.SnapshotTest exposing (suite)

import Expect
import List.Extra
import Motorsport.BestTimes as BestTimes
import Motorsport.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector(..))
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
                        |> List.map (\car -> ( car.standing.position, car.metadata.carNumber ))
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
                        |> List.map (.standing >> .gapToLeader >> Gap.toString)
                        |> List.head
                        |> Expect.equal (Just "-")
            , test "the car behind reports one" <|
                \_ ->
                    snapshotAt 7000
                        |> carAt "1"
                        |> Maybe.map (.standing >> .gapToLeader >> Gap.toString)
                        |> Expect.notEqual (Just "-")
            , test "nothing runs ahead of the leader either, so it reports no interval" <|
                \_ ->
                    snapshotAt 7000
                        |> carAt "2"
                        |> Maybe.map (.standing >> .intervalToAhead >> Gap.toString)
                        |> Expect.equal (Just "-")
            , test "and the car in second is racing the leader, so its interval is that same gap" <|
                \_ ->
                    snapshotAt 7000
                        |> carAt "1"
                        |> Maybe.map
                            (\car ->
                                Gap.toString car.standing.intervalToAhead
                                    == Gap.toString car.standing.gapToLeader
                            )
                        |> Expect.equal (Just True)
            ]
        , describe "each car is placed within its class as well as within the field"
            [ test "a class of one puts its car first, whatever it stands overall" <|
                \_ ->
                    snapshotAt 7000
                        |> Snapshot.toList
                        |> List.map (\car -> ( car.metadata.carNumber, car.standing.positionInClass ))
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
        , describe "the mini-sector a car is in, where the source data records mini-sectors"
            [ test "is the one the clock falls in, and says how far through it the car is" <|
                \_ ->
                    -- Fifteen even mini-sectors of 1.000, so 3.500 is half way
                    -- through the fourth of them in track order.
                    carAt "7" (leMansFieldAt 3500)
                        |> Maybe.andThen (.currentLap >> .miniSector)
                        |> Expect.equal (Just { miniSector = Z12, progress = 0.5 })
            , test "and where the data records none there is no mini-sector to be in, though there is still a sector" <|
                \_ ->
                    -- Away from Le Mans this is every car of every frame, which
                    -- is why `miniSector` does not go `Nothing` in step with
                    -- `sector` the way the other readings of the lap do.
                    carAt "1" (snapshotAt 7000)
                        |> Maybe.map
                            (\car ->
                                ( car.currentLap.miniSector
                                , car.currentLap.sector |> Maybe.map .sector
                                )
                            )
                        |> Expect.equal (Just ( Nothing, Just S2 ))
            ]
        , describe "the record a running lap is rated against is the car's own, at that moment"
            [ test "it is the best of the laps the car has finished, not of the one it is running" <|
                \_ ->
                    -- Car 2's second lap is a 4.000 and at 7.000 it is still on
                    -- it, so that time is not its record yet: the 5.000 of its
                    -- first lap is. The lap carries a best that counts itself,
                    -- which is why this is read off the finished lap instead.
                    carAt "2" (snapshotAt 7000)
                        |> Maybe.andThen .bestLapRated
                        |> Maybe.map .time
                        |> Expect.equal (Just 5000)
            , test "a car on its opening lap has no record to be rated against" <|
                \_ ->
                    carAt "2" (snapshotAt 3000)
                        |> Maybe.andThen .bestLapRated
                        |> Maybe.map .time
                        |> Expect.equal Nothing
            ]
        , describe "a car with no lap in progress is nowhere on the track"
            [ test "it reports no sector, as it reports no sector states" <|
                \_ ->
                    carAt "4" fieldWithTailenders
                        |> Maybe.map (\car -> ( car.currentLap.sector, car.currentLap.sectorStates ))
                        |> Expect.equal (Just ( Nothing, Nothing ))
            , test "it has completed no laps" <|
                \_ ->
                    carAt "4" fieldWithTailenders
                        |> Maybe.map (.standing >> .lapsCompleted)
                        |> Expect.equal (Just 0)
            , test "and it sorts behind every car that is running" <|
                \_ ->
                    fieldWithTailenders
                        |> Snapshot.toList
                        |> List.map (.metadata >> .carNumber)
                        |> Expect.equal [ "2", "1", "3", "4" ]
            ]
        , describe "class position is counted off the running order"
            [ test "a class of two numbers its cars 1 and 2, whatever they stand overall" <|
                \_ ->
                    Snapshot.inClass (classOf "HYPERCAR") fieldWithTailenders
                        |> List.map (\car -> ( car.metadata.carNumber, car.standing.positionInClass ))
                        |> Expect.equal [ ( "1", 1 ), ( "3", 2 ) ]
            , test "a car that is not running is still placed in its class, at the back of it" <|
                \_ ->
                    Snapshot.inClass (classOf "LMGT3") fieldWithTailenders
                        |> List.map (\car -> ( car.metadata.carNumber, car.standing.positionInClass ))
                        |> Expect.equal [ ( "2", 1 ), ( "4", 2 ) ]
            , test "a class no car races in is empty" <|
                \_ ->
                    Snapshot.inClass (classOf "LMP2") fieldWithTailenders
                        |> List.map (.metadata >> .carNumber)
                        |> Expect.equal []
            ]
        , describe "one car can be read out of the field by number"
            [ test "the car that carries the number" <|
                \_ ->
                    Snapshot.get "3" fieldWithTailenders
                        |> Maybe.map (.standing >> .position)
                        |> Expect.equal (Just 3)
            , test "and nothing for a number no car carries" <|
                \_ ->
                    Snapshot.get "99" fieldWithTailenders
                        |> Expect.equal Nothing
            ]
        , -- What `at` does with the records is BestTimes' own, and tested there.
          -- What is this module's is which of the two it asks for: at 7.000 the
          -- quickest lap run so far is a 5.000, where the race's final answer
          -- would be car 2's 4.000, still ahead of the clock.
          test "the records are the ones the race held at that moment, not the ones it ends on" <|
            \_ ->
                snapshotAt 7000
                    |> Snapshot.bestTimes
                    |> (.fastestLapTime >> BestTimes.timeOf)
                    |> Expect.equal (Just 5000)
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
carAt =
    Snapshot.get


sectorStatesOf : String -> Snapshot -> Maybe Snapshot.CurrentSectorStates
sectorStatesOf carNumber snapshot =
    carAt carNumber snapshot
        |> Maybe.andThen (.currentLap >> .sectorStates)


{-| A wider field, for what two cars cannot show: two of them sharing a class,
and one that never took to the track at all.

Read at 7.000, as the two-car fixture is, so the cars it has in common with it
stand where they stand there.

-}
fieldWithTailenders : Snapshot
fieldWithTailenders =
    Race.fromCars [ carOne, carTwo, carThree, nonStarter ]
        |> Snapshot.at { elapsed = Instant.fromDuration 7000 }


{-| Car 1's classmate, and a long way behind it: still on its opening lap at
7.000, where cars 1 and 2 are both on their second.
-}
carThree : Car
carThree =
    { metadata = metadataOf "3" (classOf "HYPERCAR")
    , startPosition = 3
    , laps = withRunningBests [ lapOf "3" 1 20000 20000 { s1 = 6000, s2 = 7000, s3 = 7000 } ]
    }


{-| A car from a circuit whose source data records mini-sectors, which the two
above are not from.

Its one lap runs for 15.000 in fifteen even mini-sectors of 1.000 apiece, so the
mini-sector a clock falls in is the clock divided by a thousand, and how far
through it is the remainder.

-}
leMansFieldAt : Duration -> Snapshot
leMansFieldAt elapsed =
    Race.fromCars [ leMansCar ]
        |> Snapshot.at { elapsed = Instant.fromDuration elapsed }


leMansCar : Car
leMansCar =
    { metadata = metadataOf "7" (classOf "HYPERCAR")
    , startPosition = 1
    , laps =
        withRunningBests
            [ lapOf "7" 1 15000 15000 { s1 = 3000, s2 = 4000, s3 = 8000 }
                |> withEvenMiniSectors 1000
            ]
    }


{-| Give a lap the fifteen mini-sectors of Le Mans, each taking `each`, so the
nth of them in track order ends `n * each` into the lap.
-}
withEvenMiniSectors : Duration -> Lap -> Lap
withEvenMiniSectors each lap =
    { lap
        | miniSectors =
            LeMans.initialize
                (\mini ->
                    let
                        position =
                            LeMans.miniSectorOrder
                                |> List.Extra.elemIndex mini
                                |> Maybe.withDefault 0
                    in
                    { time = Just each
                    , elapsed = Just (each * (position + 1))
                    , best = Nothing
                    }
                )
                |> Just
    }


{-| Fill each lap's `best` in as the loader does: the least time the car had
turned up to and including that lap, so the lap in progress carries a record
that already counts its own time.

Without this every fixture lap would carry none at all, and a test asking what
record a car held would read `Nothing` whatever the answer ought to be -- which
is exactly the shape a test of the record reading too far ahead would take.

-}
withRunningBests : List Lap -> List Lap
withRunningBests laps =
    laps
        |> List.foldl
            (\lap ( standing, acc ) ->
                let
                    best =
                        case ( standing, lap.time ) of
                            ( Just held, Just time ) ->
                                Just (min held time)

                            ( Nothing, _ ) ->
                                lap.time

                            ( _, Nothing ) ->
                                standing
                in
                ( best, { lap | best = best } :: acc )
            )
            ( Nothing, [] )
        |> Tuple.second
        |> List.reverse


{-| A car that turned no lap at all -- so it is on no lap, in no sector, and
holds no gap to anyone.
-}
nonStarter : Car
nonStarter =
    { metadata = metadataOf "4" (classOf "LMGT3")
    , startPosition = 4
    , laps = []
    }


carOne : Car
carOne =
    { metadata = metadataOf "1" (classOf "HYPERCAR")
    , startPosition = 1
    , laps =
        withRunningBests
            [ lapOf "1" 1 6000 6000 { s1 = 1000, s2 = 2000, s3 = 3000 }
            , lapOf "1" 2 6000 12000 { s1 = 1000, s2 = 2000, s3 = 3000 }
            ]
    }


carTwo : Car
carTwo =
    { metadata = metadataOf "2" (classOf "LMGT3")
    , startPosition = 2
    , laps =
        withRunningBests
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
