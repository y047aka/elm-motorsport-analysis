module Motorsport.BestTimesTest exposing (tests)

{-| Which lap took which record is counted where the laps are, in
`Round.Index`, and driven by `Round.TestIndex`. What is left here is the two
halves this module does hold: reading the round's summary, and reading the
records back at a moment of the race.
-}

import Expect
import Json.Decode as Decode
import Motorsport.BestTimes as BestTimes exposing (Changes, Holder, Snapshot)
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Sector as Sector exposing (Sector(..))
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector(..))
import Test exposing (Test, describe, test)


tests : Test
tests =
    describe "Motorsport.BestTimes"
        [ describe "reading the round's summary"
            [ test "a record is the time it stands at, and the lap that set it" <|
                \_ ->
                    finalHolderOf .fastestLapTime
                        |> Expect.equal (Just ( "2", 2, 4000 ))
            , test "each sector's records land in its own field" <|
                \_ ->
                    finalSectors
                        |> Expect.equal [ Just 1000, Just 1500, Just 1000 ]
            , test "and so do each mini-sector's, all fifteen in track order" <|
                \_ ->
                    -- Every key on the wire holds the same time as its place in
                    -- track order, so a pair swapped between fields shows up as
                    -- a time in the wrong place rather than as a decode that
                    -- fails.
                    finalMiniSectors
                        |> Expect.equal (List.range 1 15 |> List.map (\n -> Just (n * 100)))
            , test "a record no lap took is not a record standing at zero" <|
                \_ ->
                    BestTimes.final BestTimes.empty
                        |> .fastestLapTime
                        |> Expect.equal Nothing
            , test "a summary missing a record is a summary of the wrong shape" <|
                \_ ->
                    Decode.decodeString BestTimes.changesDecoder
                        """{ "fastestLapTime": [], "slowestLapTime": [] }"""
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            ]
        , describe "where the records are read"
            [ test "`at` ignores changes the clock has not reached yet" <|
                \_ ->
                    -- The quicker lap was set at 9.000, after the clock at
                    -- 7.000.
                    timeAt 7000 .fastestLapTime
                        |> Expect.equal (Just 5000)
            , test "and reads nothing at all before the first of them" <|
                \_ ->
                    timeAt 4999 .fastestLapTime
                        |> Expect.equal Nothing
            , test "`final` reads the record the race ended on, whatever the clock says" <|
                \_ ->
                    finalTime .fastestLapTime
                        |> Expect.equal (Just 4000)
            , test "who holds a record moves with the record" <|
                \_ ->
                    [ 4999, 5000, 6000, 9000 ]
                        |> List.map
                            (\elapsed ->
                                BestTimes.at { elapsed = Instant.fromDuration elapsed } changes
                                    |> .slowestLapTime
                                    |> Maybe.map .carNumber
                            )
                        |> Expect.equal [ Nothing, Just "2", Just "1", Just "1" ]
            ]
        ]



-- HELPERS


finalTime : (Snapshot -> Maybe Holder) -> Maybe Duration
finalTime pick =
    BestTimes.timeOf (pick (BestTimes.final changes))


timeAt : Duration -> (Snapshot -> Maybe Holder) -> Maybe Duration
timeAt elapsed pick =
    BestTimes.timeOf (pick (BestTimes.at { elapsed = Instant.fromDuration elapsed } changes))


finalHolderOf : (Snapshot -> Maybe Holder) -> Maybe ( String, Int, Duration )
finalHolderOf pick =
    BestTimes.final changes
        |> pick
        |> Maybe.map (\held -> ( held.carNumber, held.lap, held.time ))


finalSectors : List (Maybe Duration)
finalSectors =
    BestTimes.final changes
        |> .fastestSectors
        |> Sector.values
        |> List.map BestTimes.timeOf


finalMiniSectors : List (Maybe Duration)
finalMiniSectors =
    BestTimes.final changes
        |> .fastestMiniSectors
        |> LeMans.values
        |> List.map BestTimes.timeOf



-- FIXTURE
-- A round in which car 2 takes every record on its opening lap, ending at
-- 5.000, and some of them change hands afterwards.


changes : Changes
changes =
    case Decode.decodeString BestTimes.changesDecoder summaryIndexJson of
        Ok decoded ->
            decoded

        Err _ ->
            BestTimes.empty


summaryIndexJson : String
summaryIndexJson =
    """
    { "fastestLapTime":
        [ { "elapsed": "5.000", "time": "5.000", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" }
        , { "elapsed": "9.000", "time": "4.000", "carNumber": "2", "lap": 2, "driver": "Kamui KOBAYASHI" }
        ]
    , "slowestLapTime":
        [ { "elapsed": "5.000", "time": "5.000", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" }
        , { "elapsed": "6.000", "time": "6.000", "carNumber": "1", "lap": 1, "driver": "Will STEVENS" }
        ]
    , "sectors":
        { "s1":
            [ { "elapsed": "5.000", "time": "1.500", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" }
            , { "elapsed": "6.000", "time": "1.000", "carNumber": "1", "lap": 1, "driver": "Will STEVENS" }
            ]
        , "s2": [ { "elapsed": "5.000", "time": "1.500", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "s3": [ { "elapsed": "9.000", "time": "1.000", "carNumber": "2", "lap": 2, "driver": "Kamui KOBAYASHI" } ]
        }
    , "miniSectors":
        { "scl2":    [ { "elapsed": "5.000", "time": "0.100", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "z4":      [ { "elapsed": "5.000", "time": "0.200", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "ip1":     [ { "elapsed": "5.000", "time": "0.300", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "z12":     [ { "elapsed": "5.000", "time": "0.400", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "sclc":    [ { "elapsed": "5.000", "time": "0.500", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "a7_1":    [ { "elapsed": "5.000", "time": "0.600", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "ip2":     [ { "elapsed": "5.000", "time": "0.700", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "a8_1":    [ { "elapsed": "5.000", "time": "0.800", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "sclb":    [ { "elapsed": "5.000", "time": "0.900", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "porin":   [ { "elapsed": "5.000", "time": "1.000", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "porout":  [ { "elapsed": "5.000", "time": "1.100", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "pitref":  [ { "elapsed": "5.000", "time": "1.200", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "scl1":    [ { "elapsed": "5.000", "time": "1.300", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "fordout": [ { "elapsed": "5.000", "time": "1.400", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        , "fl":      [ { "elapsed": "5.000", "time": "1.500", "carNumber": "2", "lap": 1, "driver": "Kamui KOBAYASHI" } ]
        }
    }
    """
