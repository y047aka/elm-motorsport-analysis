module Motorsport.Lap.IntegrationTest exposing (suite)

{-| Lap型の統合テスト

設計書の「統合テスト」セクションに基づいて、
既存データとの互換性を検証し、エンドツーエンドの動作を確認する。

-}

import Expect
import Json.Decode as Decode
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Decoder exposing (lapDecoder)
import Test exposing (..)


-- 実際のレガシーJSONデータサンプル（F1からの典型的なデータ）
legacyF1LapData : String
legacyF1LapData =
    """
    {
        "carNumber": "44",
        "driver": "Lewis Hamilton",
        "lap": 15,
        "position": 2,
        "time": 89450,
        "best": 87890,
        "sector_1": 29120,
        "sector_2": 28340,
        "sector_3": 31990,
        "s1_best": 28890,
        "s2_best": 28100,
        "s3_best": 30900,
        "elapsed": 1342890
    }
    """


-- 新形式JSONデータサンプル
newFormatLapData : String
newFormatLapData =
    """
    {
        "metaData": {
            "carNumber": "33",
            "driver": "Max Verstappen"
        },
        "lap": 22,
        "position": 1,
        "timing": {
            "time": 88120,
            "best": 87650,
            "elapsed": 1785340
        },
        "sectors": {
            "sector_1": 28890,
            "sector_2": 28230,
            "sector_3": 31000,
            "s1_best": 28650,
            "s2_best": 27980,
            "s3_best": 30720
        },
        "performance": {}
    }
    """


suite : Test
suite =
    describe "Lap Integration Tests"
        [ describe "Legacy Data Compatibility"
            [ test "processes legacy F1 data correctly" <|
                \_ ->
                    case Decode.decodeString lapDecoder legacyF1LapData of
                        Ok lap ->
                            Expect.all
                                [ -- メタデータが正しく変換されている
                                  Lap.getCarNumber >> Expect.equal "44"
                                , Lap.getDriver >> Expect.equal "Lewis Hamilton"
                                  -- 基本フィールドが保持されている
                                , Lap.getLapNumber >> Expect.equal 15
                                , Lap.getPosition >> Expect.equal (Just 2)
                                  -- タイミングデータが正しく構造化されている
                                , Lap.getLapTime >> Expect.equal 89450
                                , Lap.getBestTime >> Expect.equal 87890
                                , Lap.getElapsed >> Expect.equal 1342890
                                  -- セクターデータが正しく構造化されている
                                , Lap.getSector1 >> Expect.equal 29120
                                , Lap.getSector2 >> Expect.equal 28340
                                , Lap.getSector3 >> Expect.equal 31990
                                ]
                                lap

                        Err error ->
                            Expect.fail ("Should decode legacy data: " ++ Decode.errorToString error)
            , test "maintains backward compatibility for existing code patterns" <|
                \_ ->
                    case Decode.decodeString lapDecoder legacyF1LapData of
                        Ok hamiltonLap ->
                            let
                                -- 既存コードでよく使われるパターンのテスト
                                carNumber =
                                    Lap.getCarNumber hamiltonLap

                                isLewis =
                                    Lap.getDriver hamiltonLap == "Lewis Hamilton"

                                totalSectorTime =
                                    Lap.getSector1 hamiltonLap
                                        + Lap.getSector2 hamiltonLap
                                        + Lap.getSector3 hamiltonLap

                                isCompletedLap =
                                    Lap.getLapTime hamiltonLap > 0
                            in
                            Expect.all
                                [ \_ -> Expect.equal "44" carNumber
                                , \_ -> Expect.equal True isLewis
                                , \_ -> Expect.equal 89450 totalSectorTime
                                , \_ -> Expect.equal True isCompletedLap
                                ]
                                ()

                        Err error ->
                            Expect.fail ("Should process for compatibility patterns: " ++ Decode.errorToString error)
            ]
        , describe "New Format Processing"
            [ test "processes new format data correctly" <|
                \_ ->
                    case Decode.decodeString lapDecoder newFormatLapData of
                        Ok lap ->
                            Expect.all
                                [ -- メタデータが直接読み込まれている
                                  Lap.getCarNumber >> Expect.equal "33"
                                , Lap.getDriver >> Expect.equal "Max Verstappen"
                                  -- アクセサー関数が新形式でも動作
                                , Lap.getLapNumber >> Expect.equal 22
                                , Lap.getPosition >> Expect.equal (Just 1)
                                , Lap.getLapTime >> Expect.equal 88120
                                , Lap.getBestTime >> Expect.equal 87650
                                , Lap.getElapsed >> Expect.equal 1785340
                                ]
                                lap

                        Err error ->
                            Expect.fail ("Should decode new format: " ++ Decode.errorToString error)
            ]
        , describe "Format Detection and Conversion"
            [ test "correctly identifies and processes different formats" <|
                \_ ->
                    let
                        processLapData jsonString expectedCarNumber expectedDriver =
                            case Decode.decodeString lapDecoder jsonString of
                                Ok lap ->
                                    ( Lap.getCarNumber lap, Lap.getDriver lap )

                                Err _ ->
                                    ( "ERROR", "ERROR" )

                        legacyResult =
                            processLapData legacyF1LapData "44" "Lewis Hamilton"

                        newFormatResult =
                            processLapData newFormatLapData "33" "Max Verstappen"
                    in
                    Expect.all
                        [ \_ -> Expect.equal ( "44", "Lewis Hamilton" ) legacyResult
                        , \_ -> Expect.equal ( "33", "Max Verstappen" ) newFormatResult
                        ]
                        ()
            ]
        , describe "Data Structure Consistency"
            [ test "ensures consistent data access across formats" <|
                \_ ->
                    let
                        decodeBothFormats =
                            ( Decode.decodeString lapDecoder legacyF1LapData
                            , Decode.decodeString lapDecoder newFormatLapData
                            )
                    in
                    case decodeBothFormats of
                        ( Ok legacyLap, Ok newLap ) ->
                            let
                                -- 両方の形式で同じアクセサー関数が使用可能
                                legacyAccessorCheck =
                                    [ Lap.getCarNumber legacyLap |> String.isEmpty |> not
                                    , Lap.getDriver legacyLap |> String.isEmpty |> not
                                    , Lap.getLapNumber legacyLap > 0
                                    , Lap.getLapTime legacyLap > 0
                                    ]

                                newFormatAccessorCheck =
                                    [ Lap.getCarNumber newLap |> String.isEmpty |> not
                                    , Lap.getDriver newLap |> String.isEmpty |> not
                                    , Lap.getLapNumber newLap > 0
                                    , Lap.getLapTime newLap > 0
                                    ]
                            in
                            Expect.all
                                [ \_ -> Expect.equal [ True, True, True, True ] legacyAccessorCheck
                                , \_ -> Expect.equal [ True, True, True, True ] newFormatAccessorCheck
                                ]
                                ()

                        _ ->
                            Expect.fail "Both formats should decode successfully"
            ]
        , describe "Empty and Edge Cases"
            [ test "handles empty lap creation and comparison" <|
                \_ ->
                    let
                        emptyLap =
                            Lap.empty

                        isEmptyProperlyStructured =
                            [ Lap.getCarNumber emptyLap == ""
                            , Lap.getDriver emptyLap == ""
                            , Lap.getLapNumber emptyLap == 0
                            , Lap.getPosition emptyLap == Nothing
                            , Lap.getLapTime emptyLap == 0
                            , Lap.getBestTime emptyLap == 0
                            , Lap.getElapsed emptyLap == 0
                            ]
                    in
                    Expect.equal [ True, True, True, True, True, True, True ] isEmptyProperlyStructured
            ]
        ]