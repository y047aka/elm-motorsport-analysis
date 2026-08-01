module Motorsport.BestTimesTest exposing (tests)

import Expect
import Motorsport.BestTimes as BestTimes exposing (Changes, Holder, Snapshot)
import Motorsport.Circuit.LeMans as LeMans
import Motorsport.Class as Class
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race as Race
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Sector as Sector exposing (Sector(..))
import Test exposing (Test, describe, test)


tests : Test
tests =
    describe "Motorsport.BestTimes"
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
                        |> List.map (\elapsed -> timeAt elapsed .fastestLapTime cars)
                        |> Expect.equal [ 0, 0, 6000, 6000, 5000 ]
            , test "a lap with no recorded time is not the quickest" <|
                \_ ->
                    [ car "1" [ lap 1 0 anySectors, lap 2 6000 anySectors ] ]
                        |> finalTime .fastestLapTime
                        |> Expect.equal 6000
            ]
        , describe "slowestLapTime"
            [ test "stands at the slowest lap run so far" <|
                \_ ->
                    [ car "1" [ lap 1 6000 anySectors, lap 2 5000 anySectors ] ]
                        |> finalTime .slowestLapTime
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
                        |> finalMiniSectors
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
                        |> sectorsAt 6000
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
        , describe "who holds each record"
            [ test "is the car and lap that set it" <|
                \_ ->
                    [ car "1" [ lap 1 6000 anySectors ]
                    , car "2" [ lap 1 6000 anySectors, lap 2 5000 anySectors ]
                    ]
                        |> finalHolderOf .fastestLapTime
                        |> Expect.equal (Just ( "2", 2, 5000 ))
            , test "is read per record, so a sector can belong to a car that holds no lap record" <|
                \_ ->
                    -- Car 1 is quickest through S1 without ever running the
                    -- quickest lap.
                    [ car "1" [ lap 1 6000 ( 1000, 2000, 3000 ) ]
                    , car "2" [ lap 1 5000 ( 1100, 1900, 2900 ) ]
                    ]
                        |> finalHolderOf (.fastestSectors >> Sector.get S1)
                        |> Expect.equal (Just ( "1", 1, 1000 ))
            , test "moves to whoever beat the record, as the record moves" <|
                \_ ->
                    let
                        cars =
                            [ car "1" [ lap 1 6000 anySectors ]
                            , car "2" [ lap 1 6000 anySectors, lap 2 5000 anySectors ]
                            ]
                    in
                    -- Car 2's quicker lap ends at 10.000; before that the
                    -- record is car 1's, taken first at 6.000.
                    [ 0, 6000, 10000 ]
                        |> List.map
                            (\elapsed ->
                                BestTimes.at { elapsed = elapsed } (changesOf cars)
                                    |> .fastestLapTime
                                    |> Maybe.map .carNumber
                            )
                        |> Expect.equal [ Nothing, Just "1", Just "2" ]
            , test "a record no lap has set has no holder" <|
                \_ ->
                    [ car "1" [ lap 1 0 anySectors ] ]
                        |> finalHolderOf .fastestLapTime
                        |> Expect.equal Nothing
            ]
        ]



-- HELPERS


{-| One record as a plain time, at the end of the race.
-}
finalTime : (Snapshot -> Maybe Holder) -> List Car -> Duration
finalTime pick cars =
    BestTimes.timeOf (pick (BestTimes.final (changesOf cars)))


{-| The same, as it stood at `elapsed`.
-}
timeAt : Duration -> (Snapshot -> Maybe Holder) -> List Car -> Duration
timeAt elapsed pick cars =
    BestTimes.timeOf (pick (BestTimes.at { elapsed = elapsed } (changesOf cars)))


{-| Built the way the app builds them -- through `Race.fromCars`, rather than
calling `fromLaps` on a lap list assembled here, so that the race handing its
laps over stays covered too.
-}
changesOf : List Car -> Changes
changesOf cars =
    (Race.fromCars cars).bestTimeChanges


{-| One record's holder at the end of the race, as the three things that say
which lap took it.
-}
finalHolderOf : (Snapshot -> Maybe Holder) -> List Car -> Maybe ( String, Int, Duration )
finalHolderOf pick cars =
    changesOf cars
        |> BestTimes.final
        |> pick
        |> Maybe.map (\held -> ( held.carNumber, held.lap, held.time ))


{-| The three fastest sector times in sector order, over the whole race.
-}
finalSectors : List Car -> List Duration
finalSectors cars =
    BestTimes.final (changesOf cars)
        |> .fastestSectors
        |> Sector.values
        |> List.map BestTimes.timeOf


{-| The same three, as they stood at `elapsed`.
-}
sectorsAt : Duration -> List Car -> List Duration
sectorsAt elapsed cars =
    BestTimes.at { elapsed = elapsed } (changesOf cars)
        |> .fastestSectors
        |> Sector.values
        |> List.map BestTimes.timeOf


{-| Every mini-sector record in track order, over the whole race.
-}
finalMiniSectors : List Car -> List Duration
finalMiniSectors cars =
    BestTimes.final (changesOf cars)
        |> .fastestMiniSectors
        |> LeMans.values
        |> List.map BestTimes.timeOf


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


{-| The car's number is stamped onto every lap it ran, the way the loaded data
has it -- which is where a record's holder is read from.
-}
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
    , laps = List.map (\lap_ -> { lap_ | carNumber = carNumber }) laps
    }
