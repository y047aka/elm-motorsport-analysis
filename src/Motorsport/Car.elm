module Motorsport.Car exposing (Car)

import Motorsport.Lap exposing (Lap)


type alias Car =
    { carNumber : String
    , driverName : String
    , laps : List Lap
    }
