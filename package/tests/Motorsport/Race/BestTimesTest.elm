module Motorsport.Race.BestTimesTest exposing (tests)

import Expect
import Motorsport.Circuit.LeMans as LeMans
import Motorsport.Class as Class
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race as Race
import Motorsport.Race.BestTimes as BestTimes exposing (BestTimes, Snapshot)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Sector as Sector
import Test exposing (Test, describe, test)


tests : Test
tests =
    describe "Motorsport.Race.BestTimes"
        [ describe "fastestSectors"
            [ test "takes each sector from whichever car was quickest through it" <|
                \_ ->
                    -- No car holds all three: car 1 owns S1, car 2 owns S2 and S3.
                    [ car "1" [ lap 1 6000 ( 1000, 2000, 3000 ) ]
                    , car "2" [ lap 1 6000 ( 1100, 1900, 2900 ) ]
                    ]
                        |> finalSectors
                        |> Expect.equal [ 1000, 1900, 2900 ]
            , test "ignores a sector with no recorded time rather than calling it the quickest" <|
                \_ ->
                    [ car "1" [ lap 1 6000 ( 1000, 2000, 3000 ) ]
                    , car "2" [ lap 1 6000 ( 0, 0, 0 ) ]
                    ]
                        |> finalSectors
                        |> Expect.equal [ 1000, 2000, 3000 ]
            ]
        , describe "fastestLapTime"
            [ test "stands at the quickest lap run so far, and moves when it is beaten" <|
                \_ ->
                    let
                        -- Lap 1 ends at 6.000 and lap 2 at 10.000, the quicker of
                        -- the two.
                        cars =
                            [ car "1" [ lap 1 6000 anySectors, lap 2 5000 anySectors ] ]
                    in
                    [ 0, 5999, 6000, 9999, 10000 ]
                        |> List.map (\elapsed -> (at elapsed cars).fastestLapTime)
                        |> Expect.equal [ 0, 0, 6000, 6000, 5000 ]
            , test "a lap with no recorded time is not the quickest" <|
                \_ ->
                    [ car "1" [ lap 1 0 anySectors, lap 2 6000 anySectors ] ]
                        |> final
                        |> .fastestLapTime
                        |> Expect.equal 6000
            ]
        , describe "slowestLapTime"
            [ test "stands at the slowest lap run so far" <|
                \_ ->
                    [ car "1" [ lap 1 6000 anySectors, lap 2 5000 anySectors ] ]
                        |> final
                        |> .slowestLapTime
                        |> Expect.equal 6000
            ]
        , describe "fastestMiniSectors"
            [ test "ignores the mini-sectors of a lap that has no lap time" <|
                \_ ->
                    -- The quicker mini-sectors belong to the lap with no time,
                    -- which the whole-race calculation has always thrown out.
                    [ car "1"
                        [ lap 1 0 anySectors |> withMiniSectorsOf 1000
                        , lap 2 6000 anySectors |> withMiniSectorsOf 2000
                        ]
                    ]
                        |> final
                        |> .fastestMiniSectors
                        |> LeMans.values
                        |> Expect.equal (List.repeat 15 2000)
            ]
        , describe "where the records are read"
            [ test "`at` ignores laps the clock has not reached yet" <|
                \_ ->
                    -- The quicker lap ends at 12.000, after the clock at 6.000.
                    [ car "1"
                        [ lap 1 6000 ( 1000, 2000, 3000 )
                        , lap 2 6000 ( 900, 1900, 2900 )
                        ]
                    ]
                        |> at 6000
                        |> .fastestSectors
                        |> Sector.values
                        |> Expect.equal [ 1000, 2000, 3000 ]
            , test "`final` counts every lap, whatever the clock says" <|
                \_ ->
                    [ car "1"
                        [ lap 1 6000 ( 1000, 2000, 3000 )
                        , lap 2 6000 ( 900, 1900, 2900 )
                        ]
                    ]
                        |> finalSectors
                        |> Expect.equal [ 900, 1900, 2900 ]
            ]
        ]



-- HELPERS


{-| The records a race made of these cars ends up with.
-}
final : List Car -> Snapshot
final cars =
    BestTimes.final (recordsOf cars)


{-| The records as they stood at `elapsed`.
-}
at : Duration -> List Car -> Snapshot
at elapsed cars =
    BestTimes.at { elapsed = elapsed } (recordsOf cars)


recordsOf : List Car -> BestTimes
recordsOf cars =
    (Race.fromCars cars).bestTimes


{-| The three fastest sector times in sector order, over the whole race.
-}
finalSectors : List Car -> List Duration
finalSectors cars =
    final cars
        |> .fastestSectors
        |> Sector.values


{-| A lap of `time`, split into the three given sector times, running from the
end of the previous lap of the same length.
-}
lap : Int -> Duration -> ( Duration, Duration, Duration ) -> Lap
lap lapNumber time ( s1, s2, s3 ) =
    { empty
        | lap = lapNumber
        , time = time
        , elapsed = lapNumber * time
        , sectors =
            { s1 = { time = s1, personalBest = s1 }
            , s2 = { time = s2, personalBest = s2 }
            , s3 = { time = s3, personalBest = s3 }
            }
    }


{-| Sector times for the tests that are not about sectors.
-}
anySectors : ( Duration, Duration, Duration )
anySectors =
    ( 1000, 2000, 3000 )


{-| Every mini-sector of the lap taking the same time.
-}
withMiniSectorsOf : Duration -> Lap -> Lap
withMiniSectorsOf time lap_ =
    { lap_
        | miniSectors =
            Just (LeMans.initialize (\_ -> { time = Just time, elapsed = Nothing, best = Nothing }))
    }


{-| Record update syntax needs a bare name, so `Lap.empty` gets one.
-}
empty : Lap
empty =
    Lap.empty


car : CarNumber -> List Lap -> Car
car carNumber laps =
    { metadata =
        { carNumber = carNumber
        , class = Class.none
        , group = "Test Group"
        , team = "Test Team"
        , drivers = [ Driver.fromName "Test Driver" ]
        , manufacturer = Manufacturer.Other
        }
    , startPosition = 0
    , laps = laps
    }
