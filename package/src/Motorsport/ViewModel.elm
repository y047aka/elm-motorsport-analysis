module Motorsport.ViewModel exposing (ViewModel, Scope(..), compute)

{-| The bundle of computed models handed to the view.

The single entry point of the domain → ViewModel conversion: builds every
computed model the view needs from a race and where playback has got to in it.

@docs ViewModel, Scope, compute

-}

import Motorsport.BestTimes as BestTimes
import Motorsport.Clock as Clock
import Motorsport.Replay as Replay
import Motorsport.ViewModel.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.ViewModel.Standings as Standings exposing (Standings)


type alias ViewModel =
    { standings : Standings
    , lapHistory : LapHistory
    , bestTimes : BestTimes.Snapshot
    }


{-| How wide a net the comparison baseline is drawn from.

  - `WholeRace`: every lap, whatever the clock says (playback-position-independent,
    e.g. right after data load)
  - `UpToElapsed`: only the laps completed up to the clock's elapsed time (during
    playback)

Which one is asked for decides where the race's record of its best times is read:
at the end of it, or at the clock. See [`BestTimes`](Motorsport-BestTimes).

-}
type Scope
    = WholeRace
    | UpToElapsed


compute : Scope -> Replay.Model -> ViewModel
compute scope { race, playback } =
    let
        clock =
            { elapsed = Clock.getElapsed playback }

        bestTimes =
            case scope of
                WholeRace ->
                    BestTimes.final race.bestTimes

                UpToElapsed ->
                    BestTimes.at clock race.bestTimes
    in
    { standings = Standings.compute bestTimes clock race
    , lapHistory = LapHistory.compute clock race.cars
    , bestTimes = bestTimes
    }
