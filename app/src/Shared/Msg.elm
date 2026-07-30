module Shared.Msg exposing (Msg(..))

{-| The Shared messages are defined in their own module so that `Effect` can
refer to them without creating an import cycle with `Shared`.

@docs Msg

-}

import Data.Wec as Wec
import Data.Wec.Laps as WecLaps
import Http
import Motorsport.Replay as Replay


{-| -}
type Msg
    = FetchJson_Wec { season : String, event : String }
    | JsonLoaded_Wec (Result Http.Error Wec.Event)
    | LapsLoaded_Wec (Result Http.Error (List WecLaps.RawLap))
    | ReplayMsg Replay.Msg
