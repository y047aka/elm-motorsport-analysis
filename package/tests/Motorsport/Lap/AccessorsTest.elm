module Motorsport.Lap.AccessorsTest exposing (suite)

{-| Lapアクセサー関数の単体テスト

既存コードとの互換性を確認し、新しい構造に対して
適切にアクセスできることを検証する。

-}

import Expect
import Motorsport.Lap.Accessors as LapAccessors
import Motorsport.Lap.Types exposing (Lap)
import Test exposing (..)


-- テスト用のLapデータ
testLap : Lap
testLap =
    { metaData =
        { carNumber = "44"
        , driver = "Lewis Hamilton"
        }
    , lap = 15
    , position = Just 2
    , timing =
        { time = 87500
        , best = 86200
        , elapsed = 1312500
        }
    , sectors =
        { sector_1 = 29100
        , sector_2 = 28400
        , sector_3 = 30000
        , s1_best = 28800
        , s2_best = 28100
        , s3_best = 29300
        }
    , performance = {}
    , miniSectors = Nothing
    -- 既存コードとの互換性のため
    , elapsed = 1312500
    }


suite : Test
suite =
    describe "Lap Accessors Tests"
        [ describe "MetaData Accessors"
            [ test "getCarNumber returns correct car number" <|
                \_ ->
                    testLap
                        |> LapAccessors.getCarNumber
                        |> Expect.equal "44"
            , test "getDriver returns correct driver name" <|
                \_ ->
                    testLap
                        |> LapAccessors.getDriver
                        |> Expect.equal "Lewis Hamilton"
            ]
        , describe "Timing Accessors"
            [ test "getLapTime returns correct lap time" <|
                \_ ->
                    testLap
                        |> LapAccessors.getLapTime
                        |> Expect.equal 87500
            , test "getBestTime returns correct best time" <|
                \_ ->
                    testLap
                        |> LapAccessors.getBestTime
                        |> Expect.equal 86200
            , test "getElapsed returns correct elapsed time" <|
                \_ ->
                    testLap
                        |> LapAccessors.getElapsed
                        |> Expect.equal 1312500
            ]
        , describe "Sector Accessors"
            [ test "getSector1 returns correct sector 1 time" <|
                \_ ->
                    testLap
                        |> LapAccessors.getSector1
                        |> Expect.equal 29100
            , test "getSector2 returns correct sector 2 time" <|
                \_ ->
                    testLap
                        |> LapAccessors.getSector2
                        |> Expect.equal 28400
            , test "getSector3 returns correct sector 3 time" <|
                \_ ->
                    testLap
                        |> LapAccessors.getSector3
                        |> Expect.equal 30000
            ]
        , describe "Basic Field Accessors"
            [ test "getLapNumber returns correct lap number" <|
                \_ ->
                    testLap
                        |> LapAccessors.getLapNumber
                        |> Expect.equal 15
            , test "getPosition returns correct position" <|
                \_ ->
                    testLap
                        |> LapAccessors.getPosition
                        |> Expect.equal (Just 2)
            ]
        , describe "Backwards Compatibility"
            [ test "accessors work with different lap data" <|
                \_ ->
                    let
                        differentLap =
                            { metaData =
                                { carNumber = "1"
                                , driver = "Max Verstappen"
                                }
                            , lap = 20
                            , position = Nothing
                            , timing =
                                { time = 85900
                                , best = 85900
                                , elapsed = 1718000
                                }
                            , sectors =
                                { sector_1 = 28700
                                , sector_2 = 27800
                                , sector_3 = 29400
                                , s1_best = 28700
                                , s2_best = 27800
                                , s3_best = 29400
                                }
                            , performance = {}
                            , miniSectors = Nothing
                            -- 既存コードとの互換性のため
                            , elapsed = 1718000
                            }
                    in
                    Expect.all
                        [ LapAccessors.getCarNumber >> Expect.equal "1"
                        , LapAccessors.getDriver >> Expect.equal "Max Verstappen"
                        , LapAccessors.getLapNumber >> Expect.equal 20
                        , LapAccessors.getPosition >> Expect.equal Nothing
                        , LapAccessors.getLapTime >> Expect.equal 85900
                        , LapAccessors.getBestTime >> Expect.equal 85900
                        , LapAccessors.getElapsed >> Expect.equal 1718000
                        , LapAccessors.getSector1 >> Expect.equal 28700
                        , LapAccessors.getSector2 >> Expect.equal 27800
                        , LapAccessors.getSector3 >> Expect.equal 29400
                        ]
                        differentLap
            , test "accessors handle edge cases" <|
                \_ ->
                    let
                        edgeCaseLap =
                            { metaData =
                                { carNumber = ""
                                , driver = ""
                                }
                            , lap = 0
                            , position = Nothing
                            , timing =
                                { time = 0
                                , best = 0
                                , elapsed = 0
                                }
                            , sectors =
                                { sector_1 = 0
                                , sector_2 = 0
                                , sector_3 = 0
                                , s1_best = 0
                                , s2_best = 0
                                , s3_best = 0
                                }
                            , performance = {}
                            , miniSectors = Nothing
                            -- 既存コードとの互換性のため
                            , elapsed = 0
                            }
                    in
                    Expect.all
                        [ LapAccessors.getCarNumber >> Expect.equal ""
                        , LapAccessors.getDriver >> Expect.equal ""
                        , LapAccessors.getLapNumber >> Expect.equal 0
                        , LapAccessors.getPosition >> Expect.equal Nothing
                        , LapAccessors.getLapTime >> Expect.equal 0
                        , LapAccessors.getBestTime >> Expect.equal 0
                        , LapAccessors.getElapsed >> Expect.equal 0
                        , LapAccessors.getSector1 >> Expect.equal 0
                        , LapAccessors.getSector2 >> Expect.equal 0
                        , LapAccessors.getSector3 >> Expect.equal 0
                        ]
                        edgeCaseLap
            ]
        ]