module Data.Wec.Event exposing (Event, eventDecoder)

import Data.Wec.Decoder as Wec
import Json.Decode as Decode exposing (Decoder, field, list, string)
import Motorsport.Car as Car exposing (Car)


type alias Event =
    { name : String
    , laps : List Wec.Lap
    , preprocessed : List Car
    }


eventDecoder : Decoder Event
eventDecoder =
    Decode.map3 Event
        (field "name" string)
        (field "laps" (list Wec.lapDecoder))
        (field "preprocessed" (list Car.carDecoder))
