module Data.Wec.Preprocess exposing (getPositionAt, preprocess, preprocess_)

import AssocList
import AssocList.Extra
import Data.Wec.Decoder as Wec
import List.Extra as List
import Motorsport.Car exposing (Car)
import Motorsport.Class as Class


preprocess : List Wec.Lap -> List Car
preprocess laps =
    let
        startPositions =
            List.filter (\{ lapNumber } -> lapNumber == 1) laps
                |> List.sortBy .elapsed
                |> List.map .carNumber

        ordersByLap =
            laps
                |> AssocList.Extra.groupBy .lapNumber
                |> AssocList.toList
                |> List.map
                    (\( lapNumber, cars ) ->
                        { lapNumber = lapNumber
                        , order = cars |> List.sortBy .elapsed |> List.map .carNumber
                        }
                    )
    in
    laps
        |> AssocList.Extra.groupBy .carNumber
        |> AssocList.toList
        |> List.map
            (\( carNumber, laps_ ) ->
                preprocess_
                    { carNumber = carNumber
                    , laps = laps_
                    , startPositions = startPositions
                    , ordersByLap = ordersByLap
                    }
            )


type alias OrdersByLap =
    List { lapNumber : Int, order : List String }


getPositionAt : { carNumber : String, lapNumber : Int } -> OrdersByLap -> Maybe Int
getPositionAt { carNumber, lapNumber } ordersByLap =
    ordersByLap
        |> List.find (.lapNumber >> (==) lapNumber)
        |> Maybe.andThen (.order >> List.findIndex ((==) carNumber))


preprocess_ :
    { carNumber : String
    , laps : List Wec.Lap
    , startPositions : List String
    , ordersByLap : OrdersByLap
    }
    -> Car
preprocess_ { carNumber, laps, startPositions, ordersByLap } =
    let
        { currentDriver_, class_, group_, team_, manufacturer_ } =
            List.head laps
                |> Maybe.map
                    (\{ driverName, class, group, team, manufacturer } ->
                        { currentDriver_ = driverName
                        , class_ = class
                        , group_ = group
                        , team_ = team
                        , manufacturer_ = manufacturer
                        }
                    )
                |> Maybe.withDefault
                    { class_ = Class.none
                    , team_ = ""
                    , group_ = ""
                    , currentDriver_ = ""
                    , manufacturer_ = ""
                    }

        drivers =
            List.uniqueBy .driverName laps
                |> List.map
                    (\{ driverName } ->
                        { name = driverName
                        , isCurrentDriver = driverName == currentDriver_
                        }
                    )

        startPosition =
            startPositions
                |> List.findIndex ((==) carNumber)
                |> Maybe.withDefault 0

        laps_ =
            laps
                |> List.indexedMap
                    (\index { driverName, lapNumber, lapTime, s1, s2, s3, elapsed } ->
                        { carNumber = carNumber
                        , driver = driverName
                        , lap = lapNumber
                        , position =
                            getPositionAt { carNumber = carNumber, lapNumber = lapNumber } ordersByLap
                        , time = lapTime
                        , best =
                            laps
                                |> List.take (index + 1)
                                |> List.map .lapTime
                                |> List.minimum
                                |> Maybe.withDefault 0
                        , sector_1 = Maybe.withDefault 0 s1
                        , sector_2 = Maybe.withDefault 0 s2
                        , sector_3 = Maybe.withDefault 0 s3
                        , s1_best =
                            laps
                                |> List.take (index + 1)
                                |> List.filterMap .s1
                                |> List.minimum
                                |> Maybe.withDefault 0
                        , s2_best =
                            laps
                                |> List.take (index + 1)
                                |> List.filterMap .s2
                                |> List.minimum
                                |> Maybe.withDefault 0
                        , s3_best =
                            laps
                                |> List.take (index + 1)
                                |> List.filterMap .s3
                                |> List.minimum
                                |> Maybe.withDefault 0
                        , elapsed = elapsed
                        }
                    )
    in
    { carNumber = carNumber
    , drivers = drivers
    , class = class_
    , group = group_
    , team = team_
    , manufacturer = manufacturer_
    , startPosition = startPosition
    , laps = laps_
    , currentLap = Nothing
    , lastLap = Nothing
    }
