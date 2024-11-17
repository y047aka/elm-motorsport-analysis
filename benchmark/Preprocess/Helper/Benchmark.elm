module Preprocess.Helper.Benchmark exposing (main)

import Array exposing (Array)
import Array.Extra2
import AssocList
import AssocList.Extra
import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Csv.Decode exposing (FieldNames(..))
import Data.Wec.Decoder as Wec
import Fixture


main : BenchmarkProgram
main =
    program suite


csvDecodedOfSize : Int -> List Wec.Lap
csvDecodedOfSize size =
    List.take size Fixture.csvDecoded


suite : Benchmark
suite =
    describe "Data.Wec.Preprocess"
        [ Benchmark.scale "startPositions_list"
            ([ 0 -- 32,796,129 runs/s (GoF: 99.97%)
             , 100 -- 847,795 runs/s (GoF: 99.99%)
             , 200 -- 398,531 runs/s (GoF: 99.99%)
             , 500 -- 153,345 runs/s (GoF: 99.98%)
             ]
                |> List.map (\size -> ( size, csvDecodedOfSize size ))
                |> List.map (\( size, target ) -> ( "n = " ++ String.fromInt size, \_ -> startPositions_list target ))
            )
        , Benchmark.scale "startPositions_array"
            ([ 0 -- 10,061,597 runs/s (GoF: 99.99%)
             , 100 -- 817,089 runs/s (GoF: 99.97%)
             , 200 -- 484,857 runs/s (GoF: 99.96%)
             , 500 -- 202,018 runs/s (GoF: 99.94%)
             ]
                |> List.map (\size -> ( size, csvDecodedOfSize size ))
                |> List.map (\( size, target ) -> ( "n = " ++ String.fromInt size, \_ -> startPositions_array (Array.fromList target) ))
            )
        , Benchmark.scale "ordersByLap"
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
