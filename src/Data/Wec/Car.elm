module Data.Wec.Car exposing (Car)

import Data.Wec exposing (Class)
import Data.Wec.Decoder exposing (Lap)


type alias Car =
    { carNumber : String
    , class : Class
    , group : String
    , team : String
    , manufacturer : String
    , startPosition : Int
    , positions : List Int
    , laps : List Lap
    }
