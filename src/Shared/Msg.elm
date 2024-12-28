module Shared.Msg exposing (Msg(..))

{-| -}

import Data.F1.Decoder as F1
import Data.Wec.Decoder as Wec
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
    | FetchCsv { id : String }
    | CsvLoaded (Result Http.Error (List Wec.Lap))
    | RaceControlMsg_F1 RaceControl.Msg
    | RaceControlMsg_Wec RaceControl.Msg
