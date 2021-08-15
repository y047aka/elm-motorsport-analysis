module Data.Lap.WithoutElapsed exposing (WithoutElapsed, withoutElapsedDecoder)

import Json.Decode as Decode exposing (field, float, int)


type alias WithoutElapsed =
    { lapCount : Int
    , time : Float
    }


withoutElapsedDecoder : Decode.Decoder WithoutElapsed
withoutElapsedDecoder =
    Decode.map2 WithoutElapsed
        (field "lap" int)
        (field "time" float)
