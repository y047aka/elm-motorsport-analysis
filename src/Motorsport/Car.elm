module Motorsport.Car exposing (Car)

import Data.Wec.Class exposing (Class)
import Motorsport.Lap exposing (Lap)


type alias Car =
    { carNumber : String
    , driverName : String
    , class : Class
    , group : String
    , team : String
    , manufacturer : String
    , laps : List Lap
    }
