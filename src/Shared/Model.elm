module Shared.Model exposing (Model)

{-| -}

import Motorsport.Analysis exposing (Analysis)
import Motorsport.RaceControl as RaceControl


{-| Normally, this value would live in "Shared.elm"
but that would lead to a circular dependency import cycle.

For that reason, both `Shared.Model` and `Shared.Msg` are in their
own file, so they can be imported by `Effect.elm`

-}
type alias Model =
    { raceControl_F1 : RaceControl.Model
    , raceControl_Wec : RaceControl.Model
    , analysis_F1 : Analysis
    , analysis_Wec : Analysis
    }
