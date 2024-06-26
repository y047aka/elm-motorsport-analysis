module Data.Wec.Car exposing (Car)

import Data.Wec.Class exposing (Class)
import Motorsport.Lap exposing (Lap)


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
