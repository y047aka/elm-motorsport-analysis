module Motorsport.Lap.Types exposing
    ( Lap
    , LapMetaData
    , TimingData
    , SectorData
    , PerformanceData
    , MiniSectors
    , MiniSectorData
    )

{-| 新しい統一されたLap型定義

Car型のmetaDataパターンに整合した構造で、データ構造の一貫性を向上させる。

@docs Lap, LapMetaData, TimingData, SectorData, PerformanceData, MiniSectors, MiniSectorData

-}

import Motorsport.Duration exposing (Duration)


{-| 統一されたLap型 - Car型のmetaDataパターンに整合

既存コードとの互換性のため、elapsed フィールドを追加
-}
type alias Lap =
    { metaData : LapMetaData
    , lap : Int
    , position : Maybe Int
    , timing : TimingData
    , sectors : SectorData
    , performance : PerformanceData
    , miniSectors : Maybe MiniSectors
    -- 既存コードとの互換性のためのフィールド
    , elapsed : Duration
    }


{-| Car型のMetaDataと同じ命名規則を使用したLapメタデータ
-}
type alias LapMetaData =
    { carNumber : String
    , driver : String
    }


{-| タイミング関連データの集約
-}
type alias TimingData =
    { time : Duration
    , best : Duration
    , elapsed : Duration
    }


{-| セクター情報の集約
-}
type alias SectorData =
    { sector_1 : Duration
    , sector_2 : Duration
    , sector_3 : Duration
    , s1_best : Duration
    , s2_best : Duration
    , s3_best : Duration
    }


{-| 将来拡張用のパフォーマンスデータ（現在は空）
-}
type alias PerformanceData =
    {}


{-| ミニセクターデータ構造（既存実装を参照）
-}
type alias MiniSectors =
    { scl2 : MiniSectorData
    , z4 : MiniSectorData
    , ip1 : MiniSectorData
    , z12 : MiniSectorData
    , sclc : MiniSectorData
    , a7_1 : MiniSectorData
    , ip2 : MiniSectorData
    , a8_1 : MiniSectorData
    , sclb : MiniSectorData
    , porin : MiniSectorData
    , porout : MiniSectorData
    , pitref : MiniSectorData
    , scl1 : MiniSectorData
    , fordout : MiniSectorData
    , fl : MiniSectorData
    }


{-| ミニセクターデータの個別要素
-}
type alias MiniSectorData =
    { time : Maybe Duration
    , elapsed : Maybe Duration
    , best : Maybe Duration
    }