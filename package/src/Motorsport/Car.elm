module Motorsport.Car exposing
    ( Car, Metadata, CarNumber
    , Status(..), hasRetired, statusToString
    , setStatus
    )

{-|

@docs Car, Metadata, CarNumber
@docs Status, hasRetired, statusToString
@docs setStatus

-}

import Motorsport.Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Lap exposing (Lap)
import Motorsport.Manufacturer exposing (Manufacturer)


type alias Car =
    { metadata : Metadata
    , startPosition : Int
    , laps : List Lap
    , currentLap : Maybe Lap
    , lastLap : Maybe Lap
    , status : Status
    , currentDriver : Maybe Driver
    }


type alias Metadata =
    { carNumber : CarNumber
    , drivers : List Driver
    , class : Class
    , group : String
    , team : String
    , manufacturer : Manufacturer
    }


type alias CarNumber =
    String



-- STATUS


type Status
    = PreRace
    | Racing
    | Checkered
    | Retired


hasRetired : Status -> Bool
hasRetired =
    (==) Retired


statusToString : Status -> String
statusToString status =
    case status of
        PreRace ->
            "Pre-Race"

        Racing ->
            "Racing"

        Checkered ->
            "Checkered"

        Retired ->
            "Retired"


setStatus : Status -> Car -> Car
setStatus status car =
    { car | status = status }
