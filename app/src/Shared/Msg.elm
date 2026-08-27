module Shared.Msg exposing (Msg(..))

{-| The Shared messages are defined in their own module so that `Effect` can
refer to them without creating an import cycle with `Shared`.

@docs Msg

-}

import Data.Wec as Wec
import Data.Wec.Calendar as Calendar
import Data.Wec.Laps as WecLaps
import Data.Wec.Manufacturer exposing (Manufacturers)
import Http
import Motorsport.Replay as Replay


{-| The two file responses carry the round they were asked for.

Nothing cancels an `Http.get`, so leaving a round mid-load leaves its responses
in flight. Untagged, one of them lands beside the next round's other file and
the two are assembled into a race that never ran.

-}
type Msg
    = CalendarLoaded (Result Http.Error Calendar.Calendar)
    | ManufacturersLoaded (Result Http.Error Manufacturers)
    | FetchJson_Wec { season : String, event : String }
    | JsonLoaded_Wec { season : Int, id : String } (Result Http.Error Wec.Event)
    | LapsLoaded_Wec { season : Int, id : String } (Result Http.Error (List WecLaps.RawLap))
    | ReplayMsg Replay.Msg
