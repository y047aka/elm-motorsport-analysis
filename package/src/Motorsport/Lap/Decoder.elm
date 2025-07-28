module Motorsport.Lap.Decoder exposing
    ( lapDecoder
    , metaDataDecoder
    , timingDataDecoder
    , sectorDataDecoder
    , performanceDataDecoder
    , miniSectorsDecoder
    )

{-| Lap型用の統一デコーダーシステム

新形式とレガシー形式の自動検出による互換性デコーダーを提供。
設計書の「形式自動検出システム」に基づく実装。

@docs lapDecoder, metaDataDecoder, timingDataDecoder, sectorDataDecoder
@docs performanceDataDecoder, miniSectorsDecoder

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as Pipeline
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap.Types exposing (..)


{-| 統一デコーダー（形式自動検出付き）

oneOfパターンを使用して新形式→レガシー形式の順で試行し、
透明な形式変換を実現する。
-}
lapDecoder : Decoder Lap
lapDecoder =
    Decode.oneOf
        [ newFormatDecoder
        , legacyFormatDecoder
        ]


{-| LapMetaDataデコーダー - Car型のMetaDataと同じ構造
-}
metaDataDecoder : Decoder LapMetaData
metaDataDecoder =
    Decode.succeed LapMetaData
        |> Pipeline.required "carNumber" Decode.string
        |> Pipeline.required "driver" Decode.string


{-| TimingDataデコーダー - タイミング関連データの集約
-}
timingDataDecoder : Decoder TimingData
timingDataDecoder =
    Decode.succeed TimingData
        |> Pipeline.required "time" Duration.durationDecoder
        |> Pipeline.required "best" Duration.durationDecoder
        |> Pipeline.required "elapsed" Duration.durationDecoder


{-| SectorDataデコーダー - セクター情報の集約
-}
sectorDataDecoder : Decoder SectorData
sectorDataDecoder =
    Decode.succeed SectorData
        |> Pipeline.required "sector_1" Duration.durationDecoder
        |> Pipeline.required "sector_2" Duration.durationDecoder
        |> Pipeline.required "sector_3" Duration.durationDecoder
        |> Pipeline.required "s1_best" Duration.durationDecoder
        |> Pipeline.required "s2_best" Duration.durationDecoder
        |> Pipeline.required "s3_best" Duration.durationDecoder


{-| PerformanceDataデコーダー - 将来拡張用（現在は空オブジェクト）
-}
performanceDataDecoder : Decoder PerformanceData
performanceDataDecoder =
    Decode.succeed {}


{-| MiniSectorsデコーダー - 既存のミニセクター構造に対応
-}
miniSectorsDecoder : Decoder MiniSectors
miniSectorsDecoder =
    Decode.succeed MiniSectors
        |> Pipeline.required "scl2" miniSectorDataDecoder
        |> Pipeline.required "z4" miniSectorDataDecoder
        |> Pipeline.required "ip1" miniSectorDataDecoder
        |> Pipeline.required "z12" miniSectorDataDecoder
        |> Pipeline.required "sclc" miniSectorDataDecoder
        |> Pipeline.required "a7_1" miniSectorDataDecoder
        |> Pipeline.required "ip2" miniSectorDataDecoder
        |> Pipeline.required "a8_1" miniSectorDataDecoder
        |> Pipeline.required "sclb" miniSectorDataDecoder
        |> Pipeline.required "porin" miniSectorDataDecoder
        |> Pipeline.required "porout" miniSectorDataDecoder
        |> Pipeline.required "pitref" miniSectorDataDecoder
        |> Pipeline.required "scl1" miniSectorDataDecoder
        |> Pipeline.required "fordout" miniSectorDataDecoder
        |> Pipeline.required "fl" miniSectorDataDecoder


{-| MiniSectorDataデコーダー - 個別ミニセクターデータ
-}
miniSectorDataDecoder : Decoder MiniSectorData
miniSectorDataDecoder =
    Decode.succeed MiniSectorData
        |> Pipeline.optional "time" (Decode.maybe Duration.durationDecoder) Nothing
        |> Pipeline.optional "elapsed" (Decode.maybe Duration.durationDecoder) Nothing
        |> Pipeline.optional "best" (Decode.maybe Duration.durationDecoder) Nothing


{-| 新形式用の直接デコーダー

metaDataオブジェクトから直接Lap型にマッピング
-}
newFormatDecoder : Decoder Lap
newFormatDecoder =
    Decode.succeed buildLapFromNewFormat
        |> Pipeline.required "metaData" metaDataDecoder
        |> Pipeline.required "lap" Decode.int
        |> Pipeline.optional "position" (Decode.maybe Decode.int) Nothing
        |> Pipeline.required "timing" timingDataDecoder
        |> Pipeline.required "sectors" sectorDataDecoder
        |> Pipeline.required "performance" performanceDataDecoder
        |> Pipeline.optional "miniSectors" (Decode.maybe miniSectorsDecoder) Nothing


{-| レガシー形式用の変換デコーダー

既存のフラットJSON構造から新しいLap型構造への変換
-}
legacyFormatDecoder : Decoder Lap
legacyFormatDecoder =
    Decode.succeed buildLapFromLegacy
        |> Pipeline.required "carNumber" Decode.string
        |> Pipeline.required "driver" Decode.string
        |> Pipeline.required "lap" Decode.int
        |> Pipeline.optional "position" (Decode.maybe Decode.int) Nothing
        |> Pipeline.required "time" Duration.durationDecoder
        |> Pipeline.required "best" Duration.durationDecoder
        |> Pipeline.required "sector_1" Duration.durationDecoder
        |> Pipeline.required "sector_2" Duration.durationDecoder
        |> Pipeline.required "sector_3" Duration.durationDecoder
        |> Pipeline.required "s1_best" Duration.durationDecoder
        |> Pipeline.required "s2_best" Duration.durationDecoder
        |> Pipeline.required "s3_best" Duration.durationDecoder
        |> Pipeline.required "elapsed" Duration.durationDecoder
        |> Pipeline.optional "miniSectors" (Decode.maybe miniSectorsDecoder) Nothing


{-| 新形式データからLap型への変換関数

構造化されたデータから統一Lap型に変換し、互換性フィールドを設定
-}
buildLapFromNewFormat : LapMetaData -> Int -> Maybe Int -> TimingData -> SectorData -> PerformanceData -> Maybe MiniSectors -> Lap
buildLapFromNewFormat metaData lap position timing sectors performance miniSectors =
    { metaData = metaData
    , lap = lap
    , position = position
    , timing = timing
    , sectors = sectors
    , performance = performance
    , miniSectors = miniSectors
    -- 既存コードとの互換性のため、elapsed を timing.elapsed と同期
    , elapsed = timing.elapsed
    }


{-| レガシーデータから新形式への変換関数

個別プロパティを新しい構造化されたLap型に変換
-}
buildLapFromLegacy : String -> String -> Int -> Maybe Int -> Duration -> Duration -> Duration -> Duration -> Duration -> Duration -> Duration -> Duration -> Duration -> Maybe MiniSectors -> Lap
buildLapFromLegacy carNumber driver lap position time best sector_1 sector_2 sector_3 s1_best s2_best s3_best elapsed miniSectors =
    { metaData =
        { carNumber = carNumber
        , driver = driver
        }
    , lap = lap
    , position = position
    , timing =
        { time = time
        , best = best
        , elapsed = elapsed
        }
    , sectors =
        { sector_1 = sector_1
        , sector_2 = sector_2
        , sector_3 = sector_3
        , s1_best = s1_best
        , s2_best = s2_best
        , s3_best = s3_best
        }
    , performance = {}
    , miniSectors = miniSectors
    -- 既存コードとの互換性のため、elapsed を timing.elapsed と同期
    , elapsed = elapsed
    }