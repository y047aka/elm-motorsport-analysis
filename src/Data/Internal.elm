module Data.Internal exposing (Lap)

import Data.Duration exposing (Duration)


type alias Lap =
    { lap : Int
    , time : Duration
    , best : Duration
    , elapsed : Duration
    }
