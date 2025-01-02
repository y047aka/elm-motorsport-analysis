module Data.Wec.Event exposing (Event, eventDecoder)

import Data.Wec.Decoder as Wec
import Json.Decode as Decode exposing (Decoder, field, list)


type alias Event =
    { laps : List Wec.Lap }


eventDecoder : Decoder Event
eventDecoder =
    Decode.map Event
        (field "laps" (list Wec.lapDecoder))
