module Motorsport.Lap.DecoderTest exposing (suite)

{-| Lapデコーダーの単体テスト

設計書の「ユニットテスト」セクションに基づいて、
新形式・レガシー形式両方のデコードテストを実装。

-}

import Expect
import Json.Decode as Decode
import Motorsport.Lap.Decoder exposing (lapDecoder)
import Motorsport.Lap.Types exposing (Lap)
import Test exposing (..)


suite : Test
suite =
    describe "Lap Decoder Tests"
        [ describe "New Format Decoding"
            [ test "decodes new format successfully" <|
                \_ ->
                    let
                        json =
                            """
                            {
                                "metaData": {"carNumber": "1", "driver": "Driver A"},
                                "lap": 1,
                                "timing": {"time": 90000, "best": 89000, "elapsed": 90000},
                                "sectors": {
                                    "sector_1": 30000, 
                                    "sector_2": 30000, 
                                    "sector_3": 30000, 
                                    "s1_best": 29000, 
                                    "s2_best": 29000, 
                                    "s3_best": 29000
                                },
                                "performance": {}
                            }
                            """
                    in
                    case Decode.decodeString lapDecoder json of
                        Ok lap ->
                            Expect.all
                                [ \l -> Expect.equal "1" l.metaData.carNumber
                                , \l -> Expect.equal "Driver A" l.metaData.driver
                                , \l -> Expect.equal 1 l.lap
                                , \l -> Expect.equal 90000 l.timing.time
                                , \l -> Expect.equal 89000 l.timing.best
                                , \l -> Expect.equal 90000 l.timing.elapsed
                                , \l -> Expect.equal 30000 l.sectors.sector_1
                                ]
                                lap

                        Err error ->
                            Expect.fail ("Should decode successfully: " ++ Decode.errorToString error)
            , test "decodes new format with optional fields" <|
                \_ ->
                    let
                        json =
                            """
                            {
                                "metaData": {"carNumber": "2", "driver": "Driver B"},
                                "lap": 2,
                                "position": 3,
                                "timing": {"time": 91000, "best": 90000, "elapsed": 181000},
                                "sectors": {
                                    "sector_1": 31000, 
                                    "sector_2": 30000, 
                                    "sector_3": 30000, 
                                    "s1_best": 30000, 
                                    "s2_best": 29000, 
                                    "s3_best": 29000
                                },
                                "performance": {},
                                "miniSectors": null
                            }
                            """
                    in
                    case Decode.decodeString lapDecoder json of
                        Ok lap ->
                            Expect.all
                                [ \l -> Expect.equal "2" l.metaData.carNumber
                                , \l -> Expect.equal "Driver B" l.metaData.driver
                                , \l -> Expect.equal 2 l.lap
                                , \l -> Expect.equal (Just 3) l.position
                                , \l -> Expect.equal Nothing l.miniSectors
                                ]
                                lap

                        Err error ->
                            Expect.fail ("Should decode successfully: " ++ Decode.errorToString error)
            ]
        , describe "Legacy Format Decoding"
            [ test "decodes legacy format successfully" <|
                \_ ->
                    let
                        json =
                            """
                            {
                                "carNumber": "3",
                                "driver": "Driver C", 
                                "lap": 3,
                                "time": 92000,
                                "best": 91000,
                                "sector_1": 32000,
                                "sector_2": 30000,
                                "sector_3": 30000,
                                "s1_best": 31000,
                                "s2_best": 29000,
                                "s3_best": 29000,
                                "elapsed": 275000
                            }
                            """
                    in
                    case Decode.decodeString lapDecoder json of
                        Ok lap ->
                            Expect.all
                                [ \l -> Expect.equal "3" l.metaData.carNumber
                                , \l -> Expect.equal "Driver C" l.metaData.driver
                                , \l -> Expect.equal 3 l.lap
                                , \l -> Expect.equal 92000 l.timing.time
                                , \l -> Expect.equal 91000 l.timing.best
                                , \l -> Expect.equal 275000 l.timing.elapsed
                                , \l -> Expect.equal 32000 l.sectors.sector_1
                                , \l -> Expect.equal 30000 l.sectors.sector_2
                                , \l -> Expect.equal 30000 l.sectors.sector_3
                                ]
                                lap

                        Err error ->
                            Expect.fail ("Should decode successfully: " ++ Decode.errorToString error)
            , test "decodes legacy format with optional position" <|
                \_ ->
                    let
                        json =
                            """
                            {
                                "carNumber": "4",
                                "driver": "Driver D", 
                                "lap": 4,
                                "position": 2,
                                "time": 88000,
                                "best": 87000,
                                "sector_1": 29000,
                                "sector_2": 29000,
                                "sector_3": 30000,
                                "s1_best": 28000,
                                "s2_best": 28000,
                                "s3_best": 29000,
                                "elapsed": 363000
                            }
                            """
                    in
                    case Decode.decodeString lapDecoder json of
                        Ok lap ->
                            Expect.all
                                [ \l -> Expect.equal "4" l.metaData.carNumber
                                , \l -> Expect.equal "Driver D" l.metaData.driver
                                , \l -> Expect.equal 4 l.lap
                                , \l -> Expect.equal (Just 2) l.position
                                ]
                                lap

                        Err error ->
                            Expect.fail ("Should decode successfully: " ++ Decode.errorToString error)
            ]
        , describe "Error Handling"
            [ test "fails gracefully with invalid JSON" <|
                \_ ->
                    let
                        invalidJson =
                            "{ invalid json }"
                    in
                    case Decode.decodeString lapDecoder invalidJson of
                        Ok _ ->
                            Expect.fail "Should have failed to decode invalid JSON"

                        Err _ ->
                            Expect.pass
            , test "fails gracefully with missing required fields" <|
                \_ ->
                    let
                        incompleteJson =
                            """
                            {
                                "carNumber": "5",
                                "lap": 5
                            }
                            """
                    in
                    case Decode.decodeString lapDecoder incompleteJson of
                        Ok _ ->
                            Expect.fail "Should have failed with missing required fields"

                        Err _ ->
                            Expect.pass
            , test "tries new format first, then legacy format" <|
                \_ ->
                    let
                        -- このJSONは新形式としては不完全だが、レガシー形式としては有効
                        ambiguousJson =
                            """
                            {
                                "carNumber": "6",
                                "driver": "Driver F",
                                "lap": 6,
                                "time": 89000,
                                "best": 88000,
                                "sector_1": 30000,
                                "sector_2": 29000,
                                "sector_3": 30000,
                                "s1_best": 29000,
                                "s2_best": 28000,
                                "s3_best": 29000,
                                "elapsed": 451000
                            }
                            """
                    in
                    case Decode.decodeString lapDecoder ambiguousJson of
                        Ok lap ->
                            -- レガシー形式としてデコードされ、metaDataに変換されている
                            Expect.all
                                [ \l -> Expect.equal "6" l.metaData.carNumber
                                , \l -> Expect.equal "Driver F" l.metaData.driver
                                ]
                                lap

                        Err error ->
                            Expect.fail ("Should decode as legacy format: " ++ Decode.errorToString error)
            ]
        , describe "Data Structure Conversion"
            [ test "legacy format converts to new structure correctly" <|
                \_ ->
                    let
                        legacyJson =
                            """
                            {
                                "carNumber": "7",
                                "driver": "Driver G",
                                "lap": 7,
                                "time": 90500,
                                "best": 89500,
                                "sector_1": 30500,
                                "sector_2": 30000,
                                "sector_3": 30000,
                                "s1_best": 30000,
                                "s2_best": 29500,
                                "s3_best": 29500,
                                "elapsed": 542000
                            }
                            """
                    in
                    case Decode.decodeString lapDecoder legacyJson of
                        Ok lap ->
                            Expect.all
                                [ -- metaDataが正しく生成されている
                                  \l -> Expect.equal "7" l.metaData.carNumber
                                , \l -> Expect.equal "Driver G" l.metaData.driver
                                  -- timingデータが正しく構造化されている
                                , \l -> Expect.equal 90500 l.timing.time
                                , \l -> Expect.equal 89500 l.timing.best
                                , \l -> Expect.equal 542000 l.timing.elapsed
                                  -- sectorsデータが正しく構造化されている
                                , \l -> Expect.equal 30500 l.sectors.sector_1
                                , \l -> Expect.equal 30000 l.sectors.sector_2
                                , \l -> Expect.equal 30000 l.sectors.sector_3
                                , \l -> Expect.equal 30000 l.sectors.s1_best
                                , \l -> Expect.equal 29500 l.sectors.s2_best
                                , \l -> Expect.equal 29500 l.sectors.s3_best
                                  -- performanceは空のレコード
                                , \l -> Expect.equal {} l.performance
                                ]
                                lap

                        Err error ->
                            Expect.fail ("Should decode and convert successfully: " ++ Decode.errorToString error)
            ]
        ]