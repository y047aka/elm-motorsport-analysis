module Motorsport.Car exposing
    ( Car, MetaData, Status(..)
    , updateWithClock
    )

{-|

@docs Car, MetaData, Status
@docs updateWithClock

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


updateWithClock : { elapsed : Duration } -> Car -> Car
updateWithClock raceClock car =
    { car
        | currentLap = Lap.findCurrentLap raceClock car.laps
        , lastLap = Lap.findLastLapAt raceClock car.laps
    }
        |> (\updatedCar ->
                { updatedCar
                    | status =
                        case ( updatedCar.status, isFinalLap updatedCar, isAllLapsCompleted raceClock updatedCar ) of
                            ( PreRace, _, _ ) ->
                                Racing

                            ( Racing, True, True ) ->
                                Checkered

                            ( Racing, False, True ) ->
                                Retired

                            ( Racing, _, False ) ->
                                Racing

                            ( Checkered, _, _ ) ->
                                Checkered

                            ( Retired, _, _ ) ->
                                Retired
                }
           )


isFinalLap : Car -> Bool
isFinalLap car =
    Maybe.map2 (==) car.currentLap (List.Extra.last car.laps)
        |> Maybe.withDefault False


isAllLapsCompleted : { elapsed : Duration } -> Car -> Bool
isAllLapsCompleted raceClock car =
    List.Extra.last car.laps
        |> Maybe.map (\finalLap -> finalLap.elapsed <= raceClock.elapsed)
        |> Maybe.withDefault False
