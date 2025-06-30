module Data_Cli.LeMans24h.Preprocess exposing (preprocess)

import Data_Cli.LeMans24h as LeMans24h
import Dict
import Dict.Extra
import List.Extra
import Motorsport.Car exposing (Car, Status(..))
import Motorsport.Class as Class
import Motorsport.Lap exposing (Lap)


preprocess : { a | laps : List LeMans24h.Lap } -> List Car
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
    , laps : List LeMans24h.Lap
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
            , class = class_
            , group = group_
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
    , bestSCL2 : Maybe Int
    , bestZ4 : Maybe Int
    , bestIP1 : Maybe Int
    , bestZ12 : Maybe Int
    , bestSCLC : Maybe Int
    , bestA7_1 : Maybe Int
    , bestIP2 : Maybe Int
    , bestA8_1 : Maybe Int
    , bestSCLB : Maybe Int
    , bestPORIN : Maybe Int
    , bestPOROUT : Maybe Int
    , bestPITREF : Maybe Int
    , bestSCL1 : Maybe Int
    , bestFORDOUT : Maybe Int
    , bestFL : Maybe Int
    , laps : List Lap
    }


laps_ :
    { carNumber : String
    , laps : List LeMans24h.Lap
    , ordersByLap : OrdersByLap
    }
    -> List Lap
laps_ { carNumber, laps, ordersByLap } =
    let
        step : LeMans24h.Lap -> Acc -> Acc
        step l acc =
            let
                bestLapTime =
                    List.minimum (l.lapTime :: List.filterMap identity [ acc.bestLapTime ])

                { bestS1, bestS2, bestS3 } =
                    { bestS1 = List.minimum (List.filterMap identity [ l.s1, acc.bestS1 ])
                    , bestS2 = List.minimum (List.filterMap identity [ l.s2, acc.bestS2 ])
                    , bestS3 = List.minimum (List.filterMap identity [ l.s3, acc.bestS3 ])
                    }

                ( bestSCL2, bestZ4, bestIP1 ) =
                    ( List.minimum (List.filterMap identity [ l.scl2_time, acc.bestSCL2 ])
                    , List.minimum (List.filterMap identity [ l.z4_time, acc.bestZ4 ])
                    , List.minimum (List.filterMap identity [ l.ip1_time, acc.bestIP1 ])
                    )

                { bestZ12, bestSCLC, bestA7_1, bestIP2 } =
                    { bestZ12 = List.minimum (List.filterMap identity [ l.z12_time, acc.bestZ12 ])
                    , bestSCLC = List.minimum (List.filterMap identity [ l.sclc_time, acc.bestSCLC ])
                    , bestA7_1 = List.minimum (List.filterMap identity [ l.a7_1_time, acc.bestA7_1 ])
                    , bestIP2 = List.minimum (List.filterMap identity [ l.ip2_time, acc.bestIP2 ])
                    }

                { bestA8_1, bestSCLB, bestPORIN, bestPOROUT, bestPITREF, bestSCL1, bestFORDOUT, bestFL } =
                    { bestA8_1 = List.minimum (List.filterMap identity [ l.a8_1_time, acc.bestA8_1 ])
                    , bestSCLB = List.minimum (List.filterMap identity [ l.sclb_time, acc.bestSCLB ])
                    , bestPORIN = List.minimum (List.filterMap identity [ l.porin_time, acc.bestPORIN ])
                    , bestPOROUT = List.minimum (List.filterMap identity [ l.porout_time, acc.bestPOROUT ])
                    , bestPITREF = List.minimum (List.filterMap identity [ l.pitref_time, acc.bestPITREF ])
                    , bestSCL1 = List.minimum (List.filterMap identity [ l.scl1_time, acc.bestSCL1 ])
                    , bestFORDOUT = List.minimum (List.filterMap identity [ l.fordout_time, acc.bestFORDOUT ])
                    , bestFL = List.minimum (List.filterMap identity [ l.fl_time, acc.bestFL ])
                    }

                currentLap =
                    { carNumber = carNumber
                    , driver = l.driverName
                    , lap = l.lapNumber
                    , position = getPositionAt { carNumber = carNumber, lapNumber = l.lapNumber } ordersByLap
                    , time = l.lapTime
                    , best = Maybe.withDefault 0 bestLapTime
                    , sector_1 = Maybe.withDefault 0 l.s1
                    , sector_2 = Maybe.withDefault 0 l.s2
                    , sector_3 = Maybe.withDefault 0 l.s3
                    , s1_best = Maybe.withDefault 0 bestS1
                    , s2_best = Maybe.withDefault 0 bestS2
                    , s3_best = Maybe.withDefault 0 bestS3
                    , elapsed = l.elapsed
                    , miniSectors = Just miniSectors
                    }

                miniSectors =
                    { scl2 = { time = l.scl2_time, elapsed = l.scl2_elapsed, best = bestSCL2 }
                    , z4 = { time = l.z4_time, elapsed = l.z4_elapsed, best = bestZ4 }
                    , ip1 = { time = l.ip1_time, elapsed = l.ip1_elapsed, best = bestIP1 }
                    , z12 = { time = l.z12_time, elapsed = l.z12_elapsed, best = bestZ12 }
                    , sclc = { time = l.sclc_time, elapsed = l.sclc_elapsed, best = bestSCLC }
                    , a7_1 = { time = l.a7_1_time, elapsed = l.a7_1_elapsed, best = bestA7_1 }
                    , ip2 = { time = l.ip2_time, elapsed = l.ip2_elapsed, best = bestIP2 }
                    , a8_1 = { time = l.a8_1_time, elapsed = l.a8_1_elapsed, best = bestA8_1 }
                    , sclb = { time = l.sclb_time, elapsed = l.sclb_elapsed, best = bestSCLB }
                    , porin = { time = l.porin_time, elapsed = l.porin_elapsed, best = bestPORIN }
                    , porout = { time = l.porout_time, elapsed = l.porout_elapsed, best = bestPOROUT }
                    , pitref = { time = l.pitref_time, elapsed = l.pitref_elapsed, best = bestPITREF }
                    , scl1 = { time = l.scl1_time, elapsed = l.scl1_elapsed, best = bestSCL1 }
                    , fordout = { time = l.fordout_time, elapsed = l.fordout_elapsed, best = bestFORDOUT }
                    , fl = { time = l.fl_time, elapsed = l.fl_elapsed, best = bestFL }
                    }
            in
            { bestLapTime = bestLapTime
            , bestS1 = bestS1
            , bestS2 = bestS2
            , bestS3 = bestS3
            , bestSCL2 = bestSCL2
            , bestZ4 = bestZ4
            , bestIP1 = bestIP1
            , bestZ12 = bestZ12
            , bestSCLC = bestSCLC
            , bestA7_1 = bestA7_1
            , bestIP2 = bestIP2
            , bestA8_1 = bestA8_1
            , bestSCLB = bestSCLB
            , bestPORIN = bestPORIN
            , bestPOROUT = bestPOROUT
            , bestPITREF = bestPITREF
            , bestSCL1 = bestSCL1
            , bestFORDOUT = bestFORDOUT
            , bestFL = bestFL
            , laps = currentLap :: acc.laps
            }

        initialAcc =
            { bestLapTime = Nothing
            , bestS1 = Nothing
            , bestS2 = Nothing
            , bestS3 = Nothing
            , bestSCL2 = Nothing
            , bestZ4 = Nothing
            , bestIP1 = Nothing
            , bestZ12 = Nothing
            , bestSCLC = Nothing
            , bestA7_1 = Nothing
            , bestIP2 = Nothing
            , bestA8_1 = Nothing
            , bestSCLB = Nothing
            , bestPORIN = Nothing
            , bestPOROUT = Nothing
            , bestPITREF = Nothing
            , bestSCL1 = Nothing
            , bestFORDOUT = Nothing
            , bestFL = Nothing
            , laps = []
            }
    in
    laps
        |> List.foldl step initialAcc
        |> .laps
        |> List.reverse
