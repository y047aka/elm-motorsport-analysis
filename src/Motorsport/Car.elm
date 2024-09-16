module Motorsport.Car exposing (Car)

import Motorsport.Class exposing (Class)
import Motorsport.Lap exposing (Lap)


type alias Car =
    { carNumber : String
    , drivers : List String
    , currentDriver : String
    , class : Class
    , group : String
    , team : String
    , manufacturer : String
    , startPosition : Int
    , laps : List Lap
    }
