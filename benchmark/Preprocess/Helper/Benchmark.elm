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
            ]


startPositionsSuite : List Benchmark
startPositionsSuite =
    [ Benchmark.scale "startPositions_list"
        ([ 1 -- 15,411,092 runs/s (GoF: 99.99%)
         , 10 -- 6,253,707 runs/s (GoF: 99.97%)
         , 100 -- 850,407 runs/s (GoF: 99.91%)
         , 1000 -- 76,407 runs/s (GoF: 99.91%)
         ]
            |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
            |> List.map (\( size, target ) -> ( "n = " ++ String.fromInt size, \_ -> startPositions_list target ))
        )
    , Benchmark.scale "startPositions_array"
        ([ 1 -- 4,410,251 runs/s (GoF: 99.99%)
         , 10 -- 3,240,275 runs/s (GoF: 99.98%)
         , 100 -- 847,416 runs/s (GoF: 100%)
         , 1000 -- 105,293 runs/s (GoF: 99.96%)
         ]
            |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
            |> List.map (\( size, target ) -> ( "n = " ++ String.fromInt size, \_ -> startPositions_array (Array.fromList target) ))
        )
    ]


ordersByLapSuite : List Benchmark
ordersByLapSuite =
    [ Benchmark.scale "ordersByLap"
        [ ( "ordersByLap_list"
          , \_ ->
                -- 463 runs/s (GoF: 99.99%)
                ordersByLap_list Fixture.csvDecoded
          )
        , ( "ordersByLap_array"
          , \_ ->
                -- 463 runs/s (GoF: 99.99%)
                ordersByLap_array Fixture.csvDecoded
          )
        ]
    ]


preprocess_Suite : List Benchmark
preprocess_Suite =
    let
        options =
            { carNumber = "15"
            , laps = List.filter (.carNumber >> (==) "15") Fixture.csvDecoded
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
