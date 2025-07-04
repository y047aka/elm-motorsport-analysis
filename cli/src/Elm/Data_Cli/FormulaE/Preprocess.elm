module Data_Cli.FormulaE.Preprocess exposing (preprocess)

import Data_Cli.FormulaE as FormulaE
import Dict
import Dict.Extra
import List.Extra
import Motorsport.Car exposing (Car, Status(..))
import Motorsport.Class as Class
import Motorsport.Lap exposing (Lap)


preprocess : { a | laps : List FormulaE.Lap } -> List Car
preprocess event =
    let
        startPositions =
            List.filter (\{ lapNumber } -> lapNumber == 1) event.laps
                |> List.sortBy .elapsed
                |> List.map .carNumber

        ordersByLap =
            event.laps
                |> Dict.Extra.groupBy .lapNumber
                |> Dict.toList
                |> List.map
                    (\( lapNumber, cars ) ->
                        { lapNumber = lapNumber
                        , order = cars |> List.sortBy .elapsed |> List.map .carNumber
                        }
                    )
    in
    event.laps
        |> Dict.Extra.groupBy .carNumber
        |> Dict.toList
        |> List.map
            (\( carNumber, laps__ ) ->
                preprocess_
                    { carNumber = carNumber
                    , laps = laps__
                    , startPositions = startPositions
                    , ordersByLap = ordersByLap
                    }
            )


{-| -}
type alias OrdersByLap =
    List { lapNumber : Int, order : List String }


getPositionAt : { carNumber : String, lapNumber : Int } -> OrdersByLap -> Maybe Int
getPositionAt { carNumber, lapNumber } ordersByLap =
    ordersByLap
        |> List.Extra.find (.lapNumber >> (==) lapNumber)
        |> Maybe.andThen (.order >> List.Extra.findIndex ((==) carNumber))


preprocess_ :
    { carNumber : String
    , laps : List FormulaE.Lap
    , startPositions : List String
    , ordersByLap : OrdersByLap
    }
    -> Car
preprocess_ { carNumber, laps, startPositions, ordersByLap } =
    let
        { currentDriver_, team_, manufacturer_ } =
            List.head laps
                |> Maybe.map
                    (\{ driverName,  team, manufacturer } ->
                        { currentDriver_ = driverName
                        , team_ = team
                        , manufacturer_ = manufacturer
                        }
                    )
                |> Maybe.withDefault
                    { team_ = ""
                    , currentDriver_ = ""
                    , manufacturer_ = ""
                    }

        drivers =
            List.Extra.uniqueBy .driverName laps
                |> List.map
                    (\{ driverName } ->
                        { name = driverName
                        , isCurrentDriver = driverName == currentDriver_
                        }
                    )

        metaData =
            { carNumber = carNumber
            , drivers = drivers
            , class = Class.none
            , group = ""
            , team = team_
            , manufacturer = manufacturer_
            }

        startPosition =
            startPositions
                |> List.Extra.findIndex ((==) carNumber)
                |> Maybe.withDefault 0
    in
    { metaData = metaData
    , startPosition = startPosition
    , laps =
        laps_
            { carNumber = carNumber
            , laps = laps
            , ordersByLap = ordersByLap
            }
    , currentLap = Nothing
    , lastLap = Nothing
    , status = PreRace
    }


type alias Acc =
    { bestLapTime : Maybe Int
    , bestS1 : Maybe Int
    , bestS2 : Maybe Int
    , bestS3 : Maybe Int
    , laps : List Lap
    }


laps_ :
    { carNumber : String
    , laps : List FormulaE.Lap
    , ordersByLap : OrdersByLap
    }
    -> List Lap
laps_ { carNumber, laps, ordersByLap } =
    let
        step : FormulaE.Lap -> Acc -> Acc
        step { driverName, lapNumber, lapTime, s1, s2, s3, elapsed } acc =
            let
                bestLapTime =
                    List.minimum (lapTime :: List.filterMap identity [ acc.bestLapTime ])

                ( bestS1, bestS2, bestS3 ) =
                    ( List.minimum (List.filterMap identity [ s1, acc.bestS1 ])
                    , List.minimum (List.filterMap identity [ s2, acc.bestS2 ])
                    , List.minimum (List.filterMap identity [ s3, acc.bestS3 ])
                    )

                currentLap =
                    { carNumber = carNumber
                    , driver = driverName
                    , lap = lapNumber
                    , position = getPositionAt { carNumber = carNumber, lapNumber = lapNumber } ordersByLap
                    , time = lapTime
                    , best = Maybe.withDefault 0 bestLapTime
                    , sector_1 = Maybe.withDefault 0 s1
                    , sector_2 = Maybe.withDefault 0 s2
                    , sector_3 = Maybe.withDefault 0 s3
                    , s1_best = Maybe.withDefault 0 bestS1
                    , s2_best = Maybe.withDefault 0 bestS2
                    , s3_best = Maybe.withDefault 0 bestS3
                    , elapsed = elapsed
                    , miniSectors = Nothing
                    }
            in
            { bestLapTime = bestLapTime
            , bestS1 = bestS1
            , bestS2 = bestS2
            , bestS3 = bestS3
            , laps = currentLap :: acc.laps
            }

        initialAcc =
            { bestLapTime = Nothing
            , bestS1 = Nothing
            , bestS2 = Nothing
            , bestS3 = Nothing
            , laps = []
            }
    in
    laps
        |> List.foldl step initialAcc
        |> .laps
        |> List.reverse
