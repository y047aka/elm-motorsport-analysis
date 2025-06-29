module Motorsport.Car exposing
    ( Car, MetaData
    , updateWithClock
    , Status(..), statusToString
    )

{-|

@docs Car, MetaData
@docs updateWithClock
@docs Status, statusToString

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


updateWithClock : { elapsed : Duration, timeLimit : Duration } -> Car -> Car
updateWithClock raceClock car =
    { car
        | currentLap = Lap.findCurrentLap { elapsed = raceClock.elapsed } car.laps
        , lastLap = Lap.findLastLapAt { elapsed = raceClock.elapsed } car.laps
    }
        |> (\updatedCar ->
                { updatedCar
                    | status =
                        case ( updatedCar.status, hasCompletedAllLaps raceClock updatedCar, isOnFinalLap raceClock updatedCar ) of
                            ( PreRace, _, _ ) ->
                                Racing

                            ( Racing, True, True ) ->
                                Checkered

                            ( Racing, True, False ) ->
                                Retired

                            ( Racing, False, _ ) ->
                                Racing

                            ( Checkered, _, _ ) ->
                                Checkered

                            ( Retired, _, _ ) ->
                                Retired
                }
           )


isOnFinalLap : { elapsed : Duration, timeLimit : Duration } -> Car -> Bool
isOnFinalLap raceClock car =
    let
        finishedAfterTimeLimit =
            raceClock.timeLimit <= raceClock.elapsed

        hasReachedFinalLap =
            Maybe.map2 (==) car.currentLap (List.Extra.last car.laps)
                |> Maybe.withDefault False
    in
    hasReachedFinalLap && finishedAfterTimeLimit


hasCompletedAllLaps : { a | elapsed : Duration } -> Car -> Bool
hasCompletedAllLaps raceClock car =
    List.Extra.last car.laps
        |> Maybe.map (\finalLap -> finalLap.elapsed <= raceClock.elapsed)
        |> Maybe.withDefault False
