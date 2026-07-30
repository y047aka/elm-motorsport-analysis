module Motorsport.ViewModel exposing (ViewModel, compute)

{-| The bundle of computed models handed to the view.

The single entry point of the domain → ViewModel conversion: builds every
computed model the view needs from the domain model (`RaceControl.Model`).

@docs ViewModel, compute

-}

import Motorsport.Clock as Clock
import Motorsport.RaceControl as RaceControl
import Motorsport.ViewModel.BestTimes as BestTimes exposing (BestTimes, Scope)
import Motorsport.ViewModel.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.ViewModel.Standings as Standings exposing (Standings)


type alias ViewModel =
    { standings : Standings
    , lapHistory : LapHistory
    , bestTimes : BestTimes
    }


compute : Scope -> RaceControl.Model -> ViewModel
compute scope raceControl =
    let
        elapsed =
            Clock.getElapsed raceControl.clock

        bestTimes =
            BestTimes.compute scope raceControl
    in
    { standings =
        Standings.compute bestTimes
            { elapsed = elapsed
            , lapCount = raceControl.lapCount
            , entrants = raceControl.entrants
            , statusIndex = raceControl.statusIndex
            }
    , lapHistory = LapHistory.compute { elapsed = elapsed } raceControl.entrants
    , bestTimes = bestTimes
    }
