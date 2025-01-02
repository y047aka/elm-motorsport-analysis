module Shared.Msg exposing (Msg(..))

{-| -}

import Data.F1.Decoder as F1
import Data.Wec.Event as Wec
import Http
import Motorsport.RaceControl as RaceControl


{-| Normally, this value would live in "Shared.elm"
but that would lead to a circular dependency import cycle.

For that reason, both `Shared.Model` and `Shared.Msg` are in their
own file, so they can be imported by `Effect.elm`

-}
type Msg
    = FetchJson String
    | JsonLoaded (Result Http.Error (List F1.Car))
    | FetchJson_Wec { season : String, event : String }
    | JsonLoaded_Wec (Result Http.Error Wec.Event)
    | RaceControlMsg_F1 RaceControl.Msg
    | RaceControlMsg_Wec RaceControl.Msg
