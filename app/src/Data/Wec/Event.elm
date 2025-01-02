module Data.Wec.Event exposing (Event, eventDecoder)

import Data.Wec.Decoder as Wec
import Json.Decode as Decode exposing (Decoder, field, list, string)


type alias Event =
    { name : String
    , laps : List Wec.Lap
    }


eventDecoder : Decoder Event
eventDecoder =
    Decode.map2 Event
        (field "name" string)
        (field "laps" (list Wec.lapDecoder))
