module Motorsport.ViewModel exposing (ViewModel, compute)

{-| view へ渡す計算済みモデルの束。

ドメインモデル（`RaceControl.Model` と `Analysis`）から view が必要とする
すべての計算済みモデルを構築する、ドメイン → ViewModel 変換の単一の入口。

@docs ViewModel, compute

-}

import Motorsport.Analysis exposing (Analysis)
import Motorsport.Clock as Clock
import Motorsport.RaceControl as RaceControl
import Motorsport.ViewModel.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.ViewModel.Standings as Standings exposing (Standings)


type alias ViewModel =
    { standings : Standings
    , lapHistory : LapHistory
    }


compute : { season : Int } -> Analysis -> RaceControl.Model -> ViewModel
compute season analysis raceControl =
    let
        elapsed =
            Clock.getElapsed raceControl.clock
    in
    { standings =
        Standings.compute season
            analysis
            { elapsed = elapsed
            , lapCount = raceControl.lapCount
            , cars = raceControl.cars
            }
    , lapHistory = LapHistory.compute { elapsed = elapsed } raceControl.cars
    }
