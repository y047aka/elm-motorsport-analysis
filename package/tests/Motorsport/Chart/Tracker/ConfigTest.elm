module Motorsport.Chart.Tracker.ConfigTest exposing (tests)

import Expect
import Motorsport.BestTimes exposing (Holder)
import Motorsport.Chart.Tracker.Config as Config exposing (MiniSectorShares(..), Share, TrackConfig)
import Motorsport.Circuit as Circuit
import Motorsport.Circuit.LeMans as LeMans
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Sector as Sector
import Test exposing (..)


tests : Test
tests =
    describe "Motorsport.Chart.Tracker.Config"
        [ describe "a circuit timed to sectors only"
            [ test "gives each sector the share of the lap its record is of them all" <|
                \_ ->
                    -- S1 of 1.000 against 1.000 + 2.000 + 3.000 is a sixth.
                    sectorSharesOf unevenSectors
                        |> List.map .share
                        |> expectShares [ 1 / 6, 2 / 6, 3 / 6 ]
            , test "lays them end to end from the line" <|
                \_ ->
                    sectorSharesOf unevenSectors
                        |> List.map .start
                        |> expectShares [ 0, 1 / 6, 3 / 6 ]
            , test "divides the lap evenly before any record has been set" <|
                \_ ->
                    sectorSharesOf (Config.buildConfig Circuit.clockwise noRecords)
                        |> List.map .share
                        |> expectShares [ 1 / 3, 1 / 3, 1 / 3 ]
            , test "has no mini-sectors to place a car by" <|
                \_ ->
                    (Config.buildConfig Circuit.clockwise noRecords).miniSectors
                        |> Expect.equal NoMiniSectors
            ]
        , describe "a circuit timed to mini-sectors as well"
            [ test "gives a sector what its own mini-sectors take between them" <|
                \_ ->
                    -- Fifteen equal mini-sectors, so each is a fifteenth; Le
                    -- Mans splits them 3 / 4 / 8 between the sectors. Reading a
                    -- sector off its own record instead would let the two
                    -- divisions of the lap disagree about where a sector ends.
                    sectorSharesOf evenMiniSectors
                        |> List.map .share
                        |> expectShares [ 3 / 15, 4 / 15, 8 / 15 ]
            , test "lays the mini-sectors end to end round the whole lap, not within their sector" <|
                \_ ->
                    -- The tenth in track order is in S3, and starts nine
                    -- fifteenths round the lap rather than two into its sector.
                    miniSharesOf evenMiniSectors
                        |> List.map .start
                        |> expectShares (List.map (\n -> toFloat n / 15) (List.range 0 14))
            , test "shares the whole lap out and no more" <|
                \_ ->
                    miniSharesOf evenMiniSectors
                        |> List.map .share
                        |> List.sum
                        |> Expect.within (Expect.Absolute 1.0e-9) 1
            , test "divides the lap evenly before any record has been set" <|
                \_ ->
                    -- Nothing is known about how long each stretch is until a
                    -- lap has been round, and an even fifteenth each is the
                    -- only thing that can be said then.
                    miniSharesOf (Config.buildConfig Circuit.leMans2025 noRecords)
                        |> List.map .share
                        |> expectShares (List.repeat 15 (1 / 15))
            ]
        ]



-- FIXTURES


type alias Records =
    { fastestSectors : Sector.BySector (Maybe Holder)
    , fastestMiniSectors : LeMans.ByMiniSector (Maybe Holder)
    }


{-| The records a race with no laps in it holds: none at all.
-}
noRecords : Records
noRecords =
    { fastestSectors = Sector.initialize (always Nothing)
    , fastestMiniSectors = LeMans.initialize (always Nothing)
    }


unevenSectors : TrackConfig
unevenSectors =
    Config.buildConfig Circuit.clockwise
        { noRecords
            | fastestSectors =
                { s1 = Just (holderOf 1000)
                , s2 = Just (holderOf 2000)
                , s3 = Just (holderOf 3000)
                }
        }


{-| Le Mans with every mini-sector as quick as every other, so that what a
sector comes to is decided by how many it holds and nothing else.
-}
evenMiniSectors : TrackConfig
evenMiniSectors =
    Config.buildConfig Circuit.leMans2025
        { noRecords | fastestMiniSectors = LeMans.initialize (always (Just (holderOf 1000))) }


sectorSharesOf : TrackConfig -> List Share
sectorSharesOf config =
    Sector.values config.sectors


miniSharesOf : TrackConfig -> List Share
miniSharesOf config =
    case config.miniSectors of
        MiniSectorShares shares ->
            LeMans.values shares

        NoMiniSectors ->
            []


holderOf : Duration -> Holder
holderOf time =
    { time = time, carNumber = "1", lap = 1, driver = Driver.unknown }


{-| The shares are divisions, so they land either side of the fraction they
stand for. Compares the pairs that are actually apart, so a failure names which
stretch is wrong rather than printing fifteen near-identical floats.
-}
expectShares : List Float -> List Float -> Expect.Expectation
expectShares expected actual =
    if List.length expected /= List.length actual then
        Expect.equalLists expected actual

    else
        List.map2 Tuple.pair expected actual
            |> List.filter (\( e, a ) -> abs (e - a) >= 1.0e-9)
            |> Expect.equalLists []
