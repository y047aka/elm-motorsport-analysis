module Preprocess.Helper.Benchmark exposing (main, preprocess_deprecated)

import Array exposing (Array)
import Array.Extra2
import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Data.Wec.Decoder as Wec
import Data.Wec.Preprocess
import Dict
import Dict.Extra
import Fixture.Json as Fixture
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
              ordersByLapSuite

            --   preprocess_Suite
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
            |> List.map (\size -> ( size, Fixture.jsonDecodedOfSize size ))
            |> List.map (\( size, target ) -> ( toString size, \_ -> startPositions_list target ))
        )
    , Benchmark.scale "startPositions_array"
        ([ 5 -- 3,936,471 runs/s (GoF: 99.95%)
         , 50 -- 1,500,727 runs/s (GoF: 99.97%)
         , 500 -- 230,693 runs/s (GoF: 99.96%)
         , 5000 -- 22,697 runs/s (GoF: 99.96%)
         ]
            |> List.map (\size -> ( size, Fixture.jsonDecodedOfSize size ))
            |> List.map (\( size, target ) -> ( toString size, \_ -> startPositions_array (Array.fromList target) ))
        )
    ]


ordersByLapSuite : List Benchmark
ordersByLapSuite =
    [ Benchmark.scale "ordersByLap_list"
        ([ 5 -- 945,315 runs/s (GoF: 99.99%)
         , 50 -- 64,006 runs/s (GoF: 99.98%)
         , 500 -- 5,279 runs/s (GoF: 99.99%)
         , 5000 -- 541 runs/s (GoF: 99.99%)
         ]
            |> List.map (\size -> ( size, Fixture.jsonDecodedOfSize size ))
            |> List.map (\( size, target ) -> ( toString size, \_ -> ordersByLap_list target ))
        )
    , Benchmark.scale "ordersByLap_array"
        ([ 5 -- 894,991 runs/s (GoF: 99.99%)
         , 50 -- 63,326 runs/s (GoF: 99.99%)
         , 500 -- 5,273 runs/s (GoF: 99.99%)
         , 5000 -- 541 runs/s (GoF: 99.99%)
         ]
            |> List.map (\size -> ( size, Fixture.jsonDecodedOfSize size ))
            |> List.map (\( size, target ) -> ( toString size, \_ -> ordersByLap_array target ))
        )
    ]


preprocess_Suite : List Benchmark
preprocess_Suite =
    let
        options =
            { carNumber = "15"
            , laps = jsonDecodedForCarNumber "15"
            , startPositions = startPositions_list Fixture.jsonDecoded.laps
            , ordersByLap = ordersByLap_list Fixture.jsonDecoded.laps
            }
    in
    [ Benchmark.compare "preprocess_"
        "old"
        -- 368 runs/s (GoF: 99.99%)
        (\_ -> preprocess_deprecated options)
        "improved"
        -- 2,219 runs/s (GoF: 99.98%)
        (\_ -> Data.Wec.Preprocess.preprocess_ options)
    ]


jsonDecodedForCarNumber : String -> List Wec.Lap
jsonDecodedForCarNumber str =
    List.filter (\{ carNumber } -> carNumber == str) Fixture.jsonDecoded.laps


preprocess_laps_Suite : List Benchmark
preprocess_laps_Suite =
    let
        options =
            { carNumber = "15"
            , laps = jsonDecodedForCarNumber "15"
            , ordersByLap = ordersByLap_list Fixture.jsonDecoded.laps
            }
    in
    [ Benchmark.compare "laps_"
        "old"
        -- 366 runs/s (GoF: 99.99%)
        (\_ -> laps_deprecated options)
        "improved"
        -- 2,248 runs/s (GoF: 99.96%)
        (\_ -> Data.Wec.Preprocess.laps_ options)
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
        |> Dict.Extra.groupBy .lapNumber
        |> Dict.toList
        |> List.map
            (\( lapNumber, cars ) ->
                { lapNumber = lapNumber
                , order = cars |> List.sortBy .elapsed |> List.map .carNumber
                }
            )


ordersByLap_array : List Wec.Lap -> List { lapNumber : Int, order : List String }
ordersByLap_array laps =
    laps
        |> Dict.Extra.groupBy .lapNumber
        |> Dict.toList
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
    in
    { carNumber = carNumber
    , drivers = drivers
    , class = class_
    , group = group_
    , team = team_
    , manufacturer = manufacturer_
    , startPosition = startPosition
    , laps =
        laps_deprecated
            { carNumber = carNumber
            , laps = laps
            , ordersByLap = ordersByLap
            }
    , currentLap = Nothing
    , lastLap = Nothing
    }



-- HELPERS For `preprocess_`


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
