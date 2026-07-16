module Motorsport.ViewModel.Reference exposing (Reference, Scope(..), compute)

{-| レース全体の最速値（比較基準）。

widget が個々のタイムを性能判定・スケーリングする際の基準となる集計値。
ドメインモデル（RunningOrder）を走査して構築する。

@docs Reference, Scope, compute

-}

import Motorsport.Clock as Clock
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (completedLapsAt)
import Motorsport.Lap.Performance exposing (LeMans2025MiniSectorFastest, calculateMiniSectorFastest, findFastest, findFastestBy, findSlowest)
import Motorsport.RunningOrder as RunningOrder exposing (RunningOrder)


type alias Reference =
    { fastestLapTime : Duration
    , slowestLapTime : Duration
    , fastestSector_1 : Duration
    , fastestSector_2 : Duration
    , fastestSector_3 : Duration
    , fastestMiniSectors : LeMans2025MiniSectorFastest
    }


{-| 集計スコープ。

  - `WholeRace`: 全ラップを基準にする（データ読み込み直後など、再生位置に依存しない基準値）
  - `UpToElapsed`: clock の経過時間までに完了したラップのみを基準にする（再生中）

-}
type Scope
    = WholeRace
    | UpToElapsed


compute : Scope -> { a | clock : Clock.Model, cars : RunningOrder } -> Reference
compute scope { clock, cars } =
    let
        lapsByCar =
            case scope of
                WholeRace ->
                    RunningOrder.toList cars
                        |> List.map .laps

                UpToElapsed ->
                    let
                        raceClock =
                            { elapsed = Clock.getElapsed clock }
                    in
                    RunningOrder.toList cars
                        |> List.map (.laps >> completedLapsAt raceClock)
    in
    { fastestLapTime = lapsByCar |> findFastest |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = lapsByCar |> findSlowest |> Maybe.map .time |> Maybe.withDefault 0
    , fastestSector_1 = lapsByCar |> findFastestBy .sector_1 |> Maybe.withDefault 0
    , fastestSector_2 = lapsByCar |> findFastestBy .sector_2 |> Maybe.withDefault 0
    , fastestSector_3 = lapsByCar |> findFastestBy .sector_3 |> Maybe.withDefault 0
    , fastestMiniSectors = calculateMiniSectorFastest lapsByCar
    }
