module Motorsport.Lap.Accessors exposing
    ( getCarNumber
    , getDriver
    , getElapsed
    , getSector1
    , getSector2
    , getSector3
    , getLapTime
    , getBestTime
    , getPosition
    , getLapNumber
    )

{-| 既存コードとの互換性を保つアクセサー関数群

新しいLap型の構造に対応しながら、既存のコードが変更なく動作するための
橋渡し機能を提供する。

@docs getCarNumber, getDriver, getElapsed, getSector1, getSector2, getSector3
@docs getLapTime, getBestTime, getPosition, getLapNumber

-}

import Motorsport.Duration exposing (Duration)
import Motorsport.Lap.Types exposing (Lap)


{-| Lap型からcarNumberを取得
従来: lap.carNumber
新構造: lap.metaData.carNumber
-}
getCarNumber : Lap -> String
getCarNumber lap =
    lap.metaData.carNumber


{-| Lap型からdriverを取得
従来: lap.driver
新構造: lap.metaData.driver
-}
getDriver : Lap -> String
getDriver lap =
    lap.metaData.driver


{-| Lap型からelapsed時間を取得
従来: lap.elapsed
新構造: lap.timing.elapsed
-}
getElapsed : Lap -> Duration
getElapsed lap =
    lap.timing.elapsed


{-| Lap型からセクター1時間を取得
従来: lap.sector_1
新構造: lap.sectors.sector_1
-}
getSector1 : Lap -> Duration
getSector1 lap =
    lap.sectors.sector_1


{-| Lap型からセクター2時間を取得
従来: lap.sector_2
新構造: lap.sectors.sector_2
-}
getSector2 : Lap -> Duration
getSector2 lap =
    lap.sectors.sector_2


{-| Lap型からセクター3時間を取得
従来: lap.sector_3
新構造: lap.sectors.sector_3
-}
getSector3 : Lap -> Duration
getSector3 lap =
    lap.sectors.sector_3


{-| Lap型からラップタイムを取得
従来: lap.time
新構造: lap.timing.time
-}
getLapTime : Lap -> Duration
getLapTime lap =
    lap.timing.time


{-| Lap型からベストタイムを取得
従来: lap.best
新構造: lap.timing.best
-}
getBestTime : Lap -> Duration
getBestTime lap =
    lap.timing.best


{-| Lap型からポジションを取得
構造変更なし: lap.position
-}
getPosition : Lap -> Maybe Int
getPosition lap =
    lap.position


{-| Lap型からラップ番号を取得
構造変更なし: lap.lap
-}
getLapNumber : Lap -> Int
getLapNumber lap =
    lap.lap