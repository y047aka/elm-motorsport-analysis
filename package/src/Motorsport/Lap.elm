module Motorsport.Lap exposing
    ( Lap, empty
    , compareAt
    , completedLapsAt, findLastLapAt, findCurrentLap
    , Sector(..), currentSector
    , MiniSector(..), currentMiniSector, miniSectorProgressAt
    , sectorToElapsed
    , getCarNumber, getDriver, getElapsed, getSector1, getSector2, getSector3
    , getLapTime, getBestTime, getPosition, getLapNumber
    )

{-| 統一されたLap型定義と互換性レイヤー


既存のMotorsport.Lapモジュールを新しいmetaDataパターンに対応させながら、
既存コードとの完全な互換性を維持する。

@docs Lap, empty
@docs compareAt
@docs completedLapsAt, findLastLapAt, findCurrentLap

@docs Sector, currentSector
@docs MiniSector, currentMiniSector, miniSectorProgressAt

@docs LapMetaData, TimingData, SectorData, PerformanceData
@docs getCarNumber, getDriver, getElapsed, getSector1, getSector2, getSector3
@docs getLapTime, getBestTime, getPosition, getLapNumber

-}

import List.Extra
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap.Types as Types exposing (LapMetaData, TimingData, SectorData, PerformanceData, MiniSectors, MiniSectorData)
import Motorsport.Lap.Accessors as LapAccessors


-- 新しい統一されたLap型を使用（Motorsport.Lap.Typesから）
-- 既存コードとの互換性は下記のアクセサー関数で維持

-- 型の再エクスポート
type alias Lap = Types.Lap


-- 既存コードとの互換性を保つアクセサー関数（Motorsport.Lap.Accessorsから再エクスポート）
getCarNumber : Lap -> String
getCarNumber = LapAccessors.getCarNumber


getDriver : Lap -> String
getDriver = LapAccessors.getDriver


getElapsed : Lap -> Duration
getElapsed = LapAccessors.getElapsed


getSector1 : Lap -> Duration
getSector1 = LapAccessors.getSector1


getSector2 : Lap -> Duration
getSector2 = LapAccessors.getSector2


getSector3 : Lap -> Duration
getSector3 = LapAccessors.getSector3


getLapTime : Lap -> Duration
getLapTime = LapAccessors.getLapTime


getBestTime : Lap -> Duration
getBestTime = LapAccessors.getBestTime


getPosition : Lap -> Maybe Int
getPosition = LapAccessors.getPosition


getLapNumber : Lap -> Int
getLapNumber = LapAccessors.getLapNumber


-- 新しい構造に対応したempty関数
empty : Lap
empty =
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
    -- 既存コードとの互換性のため、elapsed を timing.elapsed と同期
    , elapsed = 0
    }


type alias Clock =
    { elapsed : Duration }


-- 基本的なLap比較関数（新しい構造に対応）
compareAt : Clock -> Lap -> Lap -> Order
compareAt clock a b =
    case Basics.compare (getLapNumber a) (getLapNumber b) of
        LT ->
            GT

        EQ ->
            -- 同じラップ番号の場合はelapsed時間で比較
            Basics.compare (getElapsed a) (getElapsed b)

        GT ->
            LT


-- 完了したラップの取得（型パラメータで汎用性を保持）
completedLapsAt : Clock -> List { a | elapsed : Duration } -> List { a | elapsed : Duration }
completedLapsAt clock =
    List.filter (\lap -> lap.elapsed <= clock.elapsed)


-- 最後に完了したラップの取得
findLastLapAt : Clock -> List { a | elapsed : Duration } -> Maybe { a | elapsed : Duration }
findLastLapAt clock =
    completedLapsAt clock >> List.Extra.last


-- 現在進行中のラップの取得
findCurrentLap : Clock -> List { a | elapsed : Duration } -> Maybe { a | elapsed : Duration }
findCurrentLap clock laps =
    let
        incompletedLaps =
            List.filter (\lap -> lap.elapsed > clock.elapsed) laps
    in
    case incompletedLaps of
        [] ->
            List.Extra.last laps

        _ ->
            List.head incompletedLaps


-- セクター関連の型定義（既存互換性）
type Sector
    = S1
    | S2
    | S3


-- 現在のセクターを取得（新しい構造に対応）
currentSector : Clock -> Lap -> Sector
currentSector clock lap =
    let
        elapsed_lastLap =
            getElapsed lap - getLapTime lap
    in
    if clock.elapsed >= elapsed_lastLap && clock.elapsed < (elapsed_lastLap + getSector1 lap) then
        S1

    else if clock.elapsed >= (elapsed_lastLap + getSector1 lap) && clock.elapsed < (elapsed_lastLap + getSector1 lap + getSector2 lap) then
        S2

    else
        S3


-- セクターから経過時間への変換
sectorToElapsed : Lap -> Sector -> Duration
sectorToElapsed lap sector =
    let
        elapsed_lastLap =
            getElapsed lap - getLapTime lap
    in
    case sector of
        S1 ->
            elapsed_lastLap

        S2 ->
            elapsed_lastLap + getSector1 lap

        S3 ->
            elapsed_lastLap + getSector1 lap + getSector2 lap


-- ミニセクター関連（基本的な型定義のみ、詳細実装は将来の更新で）
type MiniSector
    = SCL2
    | Z4
    | IP1
    | Z12
    | SCLC
    | A7_1
    | IP2
    | A8_1
    | SCLB
    | PORIN
    | POROUT
    | PITREF
    | SCL1
    | FORDOUT
    | FL


-- 現在のミニセクター（簡略実装、将来詳細化）
currentMiniSector : Clock -> Lap -> Maybe MiniSector
currentMiniSector clock lap =
    -- 基本実装：miniSectorsが存在しない場合はNothing返却
    case lap.miniSectors of
        Nothing ->
            Nothing

        Just _ ->
            -- 詳細なミニセクター計算は将来実装
            Nothing


-- ミニセクターの進行状況（簡略実装）
miniSectorProgressAt : Clock -> ( Lap, Lap ) -> Maybe ( MiniSector, Float )
miniSectorProgressAt clock ( currentLap, lastLap ) =
    -- 基本実装：詳細は将来実装
    Nothing