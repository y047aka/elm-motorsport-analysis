module Motorsport.Car exposing
    ( Car, MetaData
    , updateWithClock
    , Status(..), hasRetired, statusToString
    , setStatus
    )

{-|

@docs Car, MetaData
@docs updateWithClock
@docs Status, hasRetired, statusToString
@docs setStatus

-}

import List.Extra
import Motorsport.Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap exposing (Lap)


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


updateWithClock : { elapsed : Duration, timeLimit : Duration } -> Car -> Car
updateWithClock raceClock car =
    { car
        | currentLap = Lap.findCurrentLap { elapsed = raceClock.elapsed } car.laps
        , lastLap = Lap.findLastLapAt { elapsed = raceClock.elapsed } car.laps
    }
        |> (\updatedCar ->
                { updatedCar
                    | status =
                        case ( updatedCar.status, hasCompletedAllLaps raceClock updatedCar ) of
                            ( PreRace, _ ) ->
                                Racing

                            _ ->
                                updatedCar.status
                }
           )


hasCompletedAllLaps : { a | elapsed : Duration } -> Car -> Bool
hasCompletedAllLaps raceClock car =
    List.Extra.last car.laps
        |> Maybe.map (\finalLap -> finalLap.elapsed <= raceClock.elapsed)
        |> Maybe.withDefault False
