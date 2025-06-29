module Motorsport.Car exposing (Car, MetaData, Status(..))

{-|

@docs Car, MetaData, Status

-}

import Motorsport.Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Lap exposing (Lap)


type alias Car =
    { metaData : MetaData
    , startPosition : Int
    , laps : List Lap
    , currentLap : Maybe Lap
    , lastLap : Maybe Lap
    , status : Status
    }


type alias MetaData =
    { carNumber : String
    , drivers : List Driver
    , class : Class
    , group : String
    , team : String
    , manufacturer : String
    }


type Status
    = PreRace
    | Racing
    | Checkered
    | Retired
