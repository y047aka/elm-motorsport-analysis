module Motorsport.ViewModel exposing (ViewModel, compute)

{-| The bundle of computed models handed to the view.

The single entry point of the domain → ViewModel conversion: builds every
computed model the view needs from a race and where playback has got to in it.

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
compute scope { race, playback } =
    let
        clock =
            { elapsed = Clock.getElapsed playback }

        bestTimes =
            BestTimes.compute scope clock race
    in
    { standings = Standings.compute bestTimes clock race
    , lapHistory = LapHistory.compute clock race.entrants
    , bestTimes = bestTimes
    }
