module Motorsport.ViewModel.LapHistory exposing
    ( LapHistory
    , compute
    , get, recentLaps
    )

{-| 現在時刻までに完了したラップの車両別スライス。

生の `Lap` を保持するが、時刻でスライス済みという意味で計算済みモデル層に属する。
ラップ履歴の時系列走査を必要とするチャート系モジュールだけがこれを消費する。

@docs LapHistory
@docs compute
@docs get, recentLaps

-}

import Dict exposing (Dict)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (Lap, completedLapsAt)
import Motorsport.RunningOrder as RunningOrder exposing (RunningOrder)


type LapHistory
    = LapHistory (Dict String (List Lap))


compute : { elapsed : Duration } -> RunningOrder -> LapHistory
compute raceClock cars =
    RunningOrder.toList cars
        |> List.map (\car -> ( car.metadata.carNumber, completedLapsAt raceClock car.laps ))
        |> Dict.fromList
        |> LapHistory


{-| carNumber からラップ履歴を取得する
-}
get : String -> LapHistory -> List Lap
get carNumber (LapHistory histories) =
    Dict.get carNumber histories
        |> Maybe.withDefault []


recentLaps : { count : Int, currentLap : Int } -> List Lap -> List Lap
recentLaps { count, currentLap } lapList =
    let
        targetRange =
            List.range (currentLap - count) currentLap
    in
    lapList
        |> List.filter (\lap -> List.member lap.lap targetRange)
        |> List.sortBy .lap
