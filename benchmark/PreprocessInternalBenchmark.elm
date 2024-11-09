module PreprocessInternalBenchmark exposing (main)

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


suite : Benchmark
suite =
    describe "Data.Wec.Preprocess"
        [ Benchmark.compare "startPositions"
            "startPositions_list"
            (\_ ->
                -- 127,809 runs/s (GoF: 99.98%)
                startPositions_list Fixture.csvDecoded
            )
            "startPositions_array"
            (\_ ->
                -- 168,996 runs/s (GoF: 99.96%)
                startPositions_array (Array.fromList Fixture.csvDecoded)
            )
        , Benchmark.compare "ordersByLap"
            "ordersByLap_list"
            (\_ ->
                -- 463 runs/s (GoF: 99.99%)
                ordersByLap_list Fixture.csvDecoded
            )
            "ordersByLap_array"
            (\_ ->
                -- 463 runs/s (GoF: 99.99%)
                ordersByLap_array Fixture.csvDecoded
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
