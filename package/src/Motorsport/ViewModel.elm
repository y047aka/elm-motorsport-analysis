module Motorsport.ViewModel exposing (ViewModel, compute)

{-| view へ渡す計算済みモデルの束。

ドメインモデル（`RaceControl.Model`）から view が必要とする
すべての計算済みモデルを構築する、ドメイン → ViewModel 変換の単一の入口。

@docs ViewModel, compute

-}

import Motorsport.Clock as Clock
import Motorsport.RaceControl as RaceControl
import Motorsport.ViewModel.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.ViewModel.BestTimes as BestTimes exposing (BestTimes, Scope)
import Motorsport.ViewModel.Standings as Standings exposing (Standings)


type alias ViewModel =
    { standings : Standings
    , lapHistory : LapHistory
    , bestTimes : BestTimes
    }


compute : { season : Int } -> Scope -> RaceControl.Model -> ViewModel
compute seasonConfig scope raceControl =
    let
        elapsed =
            Clock.getElapsed raceControl.clock

        bestTimes =
            BestTimes.compute scope raceControl
    in
    { standings =
        Standings.compute seasonConfig
            bestTimes
            { elapsed = elapsed
            , lapCount = raceControl.lapCount
            , cars = raceControl.cars
            }
    , lapHistory = LapHistory.compute { elapsed = elapsed } raceControl.cars
    , bestTimes = bestTimes
    }
