module Preprocess.Helper.Benchmark exposing (main)

import Array exposing (Array)
import Array.Extra2
import AssocList
import AssocList.Extra
import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Csv.Decode exposing (FieldNames(..))
import Data.Wec.Decoder as Wec
import Data.Wec.Preprocess
import Fixture
import List.Extra
import Motorsport.Car exposing (Car)
import Motorsport.Class as Class
import Motorsport.Lap exposing (Lap)


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Data.Wec.Preprocess" <|
        List.concat
            [ -- startPositionsSuite
              -- , ordersByLapSuite
              preprocess_Suite

            -- , preprocess_driversSuite
            -- , preprocess_laps_Suite
            ]


startPositionsSuite : List Benchmark
startPositionsSuite =
    [ Benchmark.scale "startPositions_list"
        ([ 5 -- 10,777,648 runs/s (GoF: 99.95%)
         , 50 -- 2,137,145 runs/s (GoF: 99.93%)
         , 500 -- 206,667 runs/s (GoF: 99.84%)
         , 5000 -- 21,238 runs/s (GoF: 99.85%)
         ]
            |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
            |> List.map (\( size, target ) -> ( toString size, \_ -> startPositions_list target ))
        )
    , Benchmark.scale "startPositions_array"
        ([ 5 -- 3,936,471 runs/s (GoF: 99.95%)
         , 50 -- 1,500,727 runs/s (GoF: 99.97%)
         , 500 -- 230,693 runs/s (GoF: 99.96%)
         , 5000 -- 22,697 runs/s (GoF: 99.96%)
         ]
            |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
            |> List.map (\( size, target ) -> ( toString size, \_ -> startPositions_array (Array.fromList target) ))
        )
    ]


ordersByLapSuite : List Benchmark
ordersByLapSuite =
    [ Benchmark.scale "ordersByLap_list"
        ([ 5 -- 1,387,510 runs/s (GoF: 99.92%)
         , 50 -- 85,140 runs/s (GoF: 99.95%)
         , 500 -- 835 runs/s (GoF: 99.94%)
         , 5000 -- 54 runs/s (GoF: 99.96%)
         ]
            |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
            |> List.map (\( size, target ) -> ( toString size, \_ -> ordersByLap_list target ))
        )
    , Benchmark.scale "ordersByLap_array"
        ([ 5 -- 1,333,480 runs/s (GoF: 99.98%)
         , 50 -- 84,749 runs/s (GoF: 99.95%)
         , 500 -- 831 runs/s (GoF: 99.94%)
         , 5000 -- 53 runs/s (GoF: 99.94%)
         ]
            |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
            |> List.map (\( size, target ) -> ( toString size, \_ -> ordersByLap_array target ))
        )
    ]


preprocess_Suite : List Benchmark
preprocess_Suite =
    let
        options =
            { carNumber = "15"
            , laps = Fixture.csvDecodedForCarNumber "15"
            , startPositions = startPositions_list Fixture.csvDecoded
            , ordersByLap = ordersByLap_list Fixture.csvDecoded
            }
    in
    [ Benchmark.compare "preprocess_"
        "old"
        -- 349 runs/s (GoF: 99.99%)
        (\_ -> preprocess_deprecated options)
        "improved"
        -- 2,215 runs/s (GoF: 99.95%)
        (\_ -> Data.Wec.Preprocess.preprocess_ options)
    ]


preprocess_driversSuite : List Benchmark
preprocess_driversSuite =
    [ Benchmark.scale "drivers"
        ([ 5 -- 10,902,054 runs/s (GoF: 99.99%)
         , 50 -- 1,952,700 runs/s (GoF: 100%)
         , 500 -- 113,370 runs/s (GoF: 99.87%)
         , 5000 -- 8,006 runs/s (GoF: 99.94%)
         ]
            |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
            |> List.map (\( size, target ) -> ( toString size, \_ -> drivers target ))
        )
    ]


preprocess_laps_Suite : List Benchmark
preprocess_laps_Suite =
    let
        options =
            { carNumber = "15"
            , laps = Fixture.csvDecodedForCarNumber "15"
            , ordersByLap = ordersByLap_list Fixture.csvDecoded
            }
    in
    [ Benchmark.compare "laps_"
        "old"
        -- 294 runs/s (GoF: 99.99%)
        (\_ -> laps_deprecated options)
        "improved"
        -- 2,199 runs/s (GoF: 99.96%)
        (\_ -> laps_improved options)
    ]


toString : Int -> String
toString n =
    "n = " ++ String.fromInt n


startPositions_list : List Wec.Lap -> List String
startPositions_list laps =
    List.filter (\{ lapNumber } -> lapNumber == 1) laps
        |> List.sortBy .elapsed
        |> List.map .carNumber


startPositions_array : Array Wec.Lap -> List String
startPositions_array laps =
    Array.filter (\{ lapNumber } -> lapNumber == 1) laps
        |> Array.Extra2.sortBy .elapsed
        |> Array.map .carNumber
        |> Array.toList


ordersByLap_list : List Wec.Lap -> List { lapNumber : Int, order : List String }
ordersByLap_list laps =
    laps
        |> AssocList.Extra.groupBy .lapNumber
        |> AssocList.toList
        |> List.map
            (\( lapNumber, cars ) ->
                { lapNumber = lapNumber
                , order = cars |> List.sortBy .elapsed |> List.map .carNumber
                }
            )


ordersByLap_array : List Wec.Lap -> List { lapNumber : Int, order : List String }
ordersByLap_array laps =
    laps
        |> AssocList.Extra.groupBy .lapNumber
        |> AssocList.toList
        |> Array.fromList
        |> Array.map
            (\( lapNumber, cars ) ->
                { lapNumber = lapNumber
                , order = cars |> List.sortBy .elapsed |> List.map .carNumber
                }
            )
        |> Array.toList


preprocess_deprecated :
    { carNumber : String
    , laps : List Wec.Lap
    , startPositions : List String
    , ordersByLap : OrdersByLap
    }
    -> Car
preprocess_deprecated { carNumber, laps, startPositions, ordersByLap } =
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

        startPosition =
            startPositions
                |> List.Extra.findIndex ((==) carNumber)
                |> Maybe.withDefault 0

        laps_ =
            laps
                |> List.indexedMap
                    (\index { driverName, lapNumber, lapTime, s1, s2, s3, elapsed } ->
                        { carNumber = carNumber
                        , driver = driverName
                        , lap = lapNumber
                        , position =
                            Data.Wec.Preprocess.getPositionAt { carNumber = carNumber, lapNumber = lapNumber } ordersByLap
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



-- HELPERS For `preprocess_`


drivers : List Wec.Lap -> List { name : String, isCurrentDriver : Bool }
drivers laps =
    let
        currentDriver_ =
            "dummyName"
    in
    laps
        |> List.Extra.uniqueBy .driverName
        |> List.map
            (\{ driverName } ->
                { name = driverName
                , isCurrentDriver = driverName == currentDriver_
                }
            )


type alias OrdersByLap =
    List { lapNumber : Int, order : List String }


laps_deprecated :
    { carNumber : String
    , laps : List Wec.Lap
    , ordersByLap : OrdersByLap
    }
    -> List Lap
laps_deprecated { carNumber, laps, ordersByLap } =
    laps
        |> List.indexedMap
            (\index { driverName, lapNumber, lapTime, s1, s2, s3, elapsed } ->
                { carNumber = carNumber
                , driver = driverName
                , lap = lapNumber
                , position =
                    Data.Wec.Preprocess.getPositionAt { carNumber = carNumber, lapNumber = lapNumber } ordersByLap
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


type alias Acc =
    { bestLapTime : Maybe Int
    , bestS1 : Maybe Int
    , bestS2 : Maybe Int
    , bestS3 : Maybe Int
    , laps : List Lap
    }


laps_improved :
    { carNumber : String
    , laps : List Wec.Lap
    , ordersByLap : OrdersByLap
    }
    -> List Lap
laps_improved { carNumber, laps, ordersByLap } =
    let
        step : Wec.Lap -> Acc -> Acc
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
                    , position = Data.Wec.Preprocess.getPositionAt { carNumber = carNumber, lapNumber = lapNumber } ordersByLap
                    , time = lapTime
                    , best = Maybe.withDefault 0 bestLapTime
                    , sector_1 = Maybe.withDefault 0 s1
                    , sector_2 = Maybe.withDefault 0 s2
                    , sector_3 = Maybe.withDefault 0 s3
                    , s1_best = Maybe.withDefault 0 bestS1
                    , s2_best = Maybe.withDefault 0 bestS2
                    , s3_best = Maybe.withDefault 0 bestS3
                    , elapsed = elapsed
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
