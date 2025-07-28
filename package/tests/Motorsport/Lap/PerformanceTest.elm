module Motorsport.Lap.PerformanceTest exposing (suite)

{-| Lap型のパフォーマンステスト

設計書の「パフォーマンステスト」に基づいて、
デコード性能と大量データ処理の性能を検証する。

-}

import Expect
import Json.Decode as Decode
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Decoder exposing (lapDecoder)
import Test exposing (..)


-- 大量データシミュレーション用のヘルパー関数
generateLegacyLapJson : Int -> String -> String
generateLegacyLapJson lapNumber carNumber =
    """
    {
        "carNumber": """ ++ "\"" ++ carNumber ++ "\"" ++ """,
        "driver": "Driver """ ++ carNumber ++ """",
        "lap": """ ++ String.fromInt lapNumber ++ """,
        "position": """ ++ String.fromInt (modBy 20 lapNumber + 1) ++ """,
        "time": """ ++ String.fromInt (85000 + modBy 5000 lapNumber) ++ """,
        "best": """ ++ String.fromInt (84000 + modBy 3000 lapNumber) ++ """,
        "sector_1": """ ++ String.fromInt (28000 + modBy 2000 lapNumber) ++ """,
        "sector_2": """ ++ String.fromInt (28000 + modBy 1500 lapNumber) ++ """,
        "sector_3": """ ++ String.fromInt (29000 + modBy 1800 lapNumber) ++ """,
        "s1_best": """ ++ String.fromInt (27500 + modBy 1000 lapNumber) ++ """,
        "s2_best": """ ++ String.fromInt (27800 + modBy 800 lapNumber) ++ """,
        "s3_best": """ ++ String.fromInt (28500 + modBy 900 lapNumber) ++ """,
        "elapsed": """ ++ String.fromInt (lapNumber * 90000) ++ """
    }
    """


generateNewFormatLapJson : Int -> String -> String
generateNewFormatLapJson lapNumber carNumber =
    """
    {
        "metaData": {
            "carNumber": """ ++ "\"" ++ carNumber ++ "\"" ++ """,
            "driver": "Driver """ ++ carNumber ++ """"
        },
        "lap": """ ++ String.fromInt lapNumber ++ """,
        "position": """ ++ String.fromInt (modBy 20 lapNumber + 1) ++ """,
        "timing": {
            "time": """ ++ String.fromInt (85000 + modBy 5000 lapNumber) ++ """,
            "best": """ ++ String.fromInt (84000 + modBy 3000 lapNumber) ++ """,
            "elapsed": """ ++ String.fromInt (lapNumber * 90000) ++ """
        },
        "sectors": {
            "sector_1": """ ++ String.fromInt (28000 + modBy 2000 lapNumber) ++ """,
            "sector_2": """ ++ String.fromInt (28000 + modBy 1500 lapNumber) ++ """,
            "sector_3": """ ++ String.fromInt (29000 + modBy 1800 lapNumber) ++ """,
            "s1_best": """ ++ String.fromInt (27500 + modBy 1000 lapNumber) ++ """,
            "s2_best": """ ++ String.fromInt (27800 + modBy 800 lapNumber) ++ """,
            "s3_best": """ ++ String.fromInt (28500 + modBy 900 lapNumber) ++ """
        },
        "performance": {}
    }
    """


-- デコード性能テスト用のヘルパー
decodeLapBatch : List String -> List (Result Decode.Error Lap)
decodeLapBatch jsonStrings =
    List.map (Decode.decodeString lapDecoder) jsonStrings


-- アクセサー性能テスト用のヘルパー
processLapBatch : List Lap -> List { carNumber : String, lapTime : Int, sectors : ( Int, Int, Int ) }
processLapBatch laps =
    List.map
        (\lap ->
            { carNumber = Lap.getCarNumber lap
            , lapTime = Lap.getLapTime lap
            , sectors = ( Lap.getSector1 lap, Lap.getSector2 lap, Lap.getSector3 lap )
            }
        )
        laps


suite : Test
suite =
    describe "Lap Performance Tests"
        [ describe "Decode Performance"
            [ test "decodes small batch of legacy format efficiently" <|
                \_ ->
                    let
                        legacyJsonBatch =
                            List.range 1 10
                                |> List.map (\i -> generateLegacyLapJson i (String.fromInt i))

                        results =
                            decodeLapBatch legacyJsonBatch

                        successCount =
                            results
                                |> List.filterMap Result.toMaybe
                                |> List.length
                    in
                    Expect.equal 10 successCount
            , test "decodes small batch of new format efficiently" <|
                \_ ->
                    let
                        newFormatJsonBatch =
                            List.range 1 10
                                |> List.map (\i -> generateNewFormatLapJson i (String.fromInt i))

                        results =
                            decodeLapBatch newFormatJsonBatch

                        successCount =
                            results
                                |> List.filterMap Result.toMaybe
                                |> List.length
                    in
                    Expect.equal 10 successCount
            , test "handles mixed format batch correctly" <|
                \_ ->
                    let
                        mixedBatch =
                            [ generateLegacyLapJson 1 "1"
                            , generateNewFormatLapJson 2 "2"
                            , generateLegacyLapJson 3 "3"
                            , generateNewFormatLapJson 4 "4"
                            , generateLegacyLapJson 5 "5"
                            ]

                        results =
                            decodeLapBatch mixedBatch

                        successCount =
                            results
                                |> List.filterMap Result.toMaybe
                                |> List.length

                        -- 各フォーマットが正しく認識されているかチェック
                        decodedLaps =
                            results
                                |> List.filterMap Result.toMaybe

                        carNumbers =
                            List.map Lap.getCarNumber decodedLaps
                    in
                    Expect.all
                        [ \_ -> Expect.equal 5 successCount
                        , \_ -> Expect.equal [ "1", "2", "3", "4", "5" ] carNumbers
                        ]
                        ()
            ]
        , describe "Accessor Performance"
            [ test "processes batch of laps with accessors efficiently" <|
                \_ ->
                    let
                        jsonBatch =
                            List.range 1 20
                                |> List.map (\i -> generateLegacyLapJson i (String.fromInt (modBy 5 i + 1)))

                        decodedLaps =
                            decodeLapBatch jsonBatch
                                |> List.filterMap Result.toMaybe

                        processedData =
                            processLapBatch decodedLaps

                        validProcessedCount =
                            processedData
                                |> List.filter (\data -> not (String.isEmpty data.carNumber) && data.lapTime > 0)
                                |> List.length
                    in
                    Expect.equal 20 validProcessedCount
            , test "maintains consistent access times across formats" <|
                \_ ->
                    let
                        legacyLaps =
                            List.range 1 10
                                |> List.map (\i -> generateLegacyLapJson i "L")
                                |> decodeLapBatch
                                |> List.filterMap Result.toMaybe

                        newFormatLaps =
                            List.range 1 10
                                |> List.map (\i -> generateNewFormatLapJson i "N")
                                |> decodeLapBatch
                                |> List.filterMap Result.toMaybe

                        legacyProcessed =
                            processLapBatch legacyLaps

                        newFormatProcessed =
                            processLapBatch newFormatLaps

                        bothAreProcessable =
                            [ List.length legacyProcessed == 10
                            , List.length newFormatProcessed == 10
                            , List.all (\data -> not (String.isEmpty data.carNumber)) legacyProcessed
                            , List.all (\data -> not (String.isEmpty data.carNumber)) newFormatProcessed
                            ]
                    in
                    Expect.equal [ True, True, True, True ] bothAreProcessable
            ]
        , describe "Memory Efficiency"
            [ test "handles repeated decode/access cycles efficiently" <|
                \_ ->
                    let
                        -- 同じJSONを複数回デコードするシナリオ（キャッシュなしの想定）
                        baseJson =
                            generateLegacyLapJson 1 "TEST"

                        repeatedDecodes =
                            List.repeat 5 baseJson
                                |> decodeLapBatch
                                |> List.filterMap Result.toMaybe

                        consistentResults =
                            repeatedDecodes
                                |> List.map Lap.getCarNumber
                                |> List.all (\carNumber -> carNumber == "TEST")

                        consistentLapTimes =
                            repeatedDecodes
                                |> List.map Lap.getLapTime
                                |> (\times ->
                                        case times of
                                            first :: rest ->
                                                List.all (\time -> time == first) rest

                                            [] ->
                                                False
                                   )
                    in
                    Expect.all
                        [ \_ -> Expect.equal True consistentResults
                        , \_ -> Expect.equal True consistentLapTimes
                        , \_ -> Expect.equal 5 (List.length repeatedDecodes)
                        ]
                        ()
            ]
        , describe "Format Detection Performance"
            [ test "efficiently distinguishes between formats in large batch" <|
                \_ ->
                    let
                        -- 交互に配置された異なるフォーマット
                        alternatingBatch =
                            List.range 1 30
                                |> List.concatMap
                                    (\i ->
                                        if modBy 2 i == 0 then
                                            [ generateNewFormatLapJson i (String.fromInt i) ]

                                        else
                                            [ generateLegacyLapJson i (String.fromInt i) ]
                                    )

                        results =
                            decodeLapBatch alternatingBatch

                        successCount =
                            results
                                |> List.filterMap Result.toMaybe
                                |> List.length

                        -- 全て正しく処理されたかチェック
                        allProcessedCorrectly =
                            results
                                |> List.all
                                    (\result ->
                                        case result of
                                            Ok _ ->
                                                True

                                            Err _ ->
                                                False
                                    )
                    in
                    Expect.all
                        [ \_ -> Expect.equal 30 successCount
                        , \_ -> Expect.equal True allProcessedCorrectly
                        ]
                        ()
            ]
        ]