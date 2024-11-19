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
import Motorsport.Lap exposing (Lap)


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Data.Wec.Preprocess" <|
        List.concat
            [ startPositionsSuite
            , ordersByLapSuite
            , preprocess_Suite

            -- ,preprocess_driversSuite
            , preprocess_laps_Suite
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
    [ Benchmark.benchmark "preprocess_"
        (\_ ->
            -- 375 runs/s (GoF: 100%)
            Data.Wec.Preprocess.preprocess_ options
        )
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
    [ Benchmark.benchmark "laps_"
        (\_ ->
            -- 351 runs/s (GoF: 99.99%)
            laps_ options
        )
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


laps_ :
    { carNumber : String
    , laps : List Wec.Lap
    , ordersByLap : OrdersByLap
    }
    -> List Lap
laps_ { carNumber, laps, ordersByLap } =
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
