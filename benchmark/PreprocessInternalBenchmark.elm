module PreprocessInternalBenchmark exposing (main)

import AssocList
import AssocList.Extra
import Benchmark exposing (Benchmark, benchmark, describe)
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
        [ benchmark "startPositions"
            (\_ ->
                -- 154,969 runs/s (GoF: 99.91%)
                startPositions Fixture.csvDecoded
            )
        , benchmark "ordersByLap"
            (\_ ->
                -- 514 runs/s (GoF: 99.98%)
                ordersByLap Fixture.csvDecoded
            )
        ]


startPositions : List Wec.Lap -> List String
startPositions laps =
    List.filter (\{ lapNumber } -> lapNumber == 1) laps
        |> List.sortBy .elapsed
        |> List.map .carNumber


ordersByLap : List Wec.Lap -> List { lapNumber : Int, order : List String }
ordersByLap laps =
    laps
        |> AssocList.Extra.groupBy .lapNumber
        |> AssocList.toList
        |> List.map
            (\( lapNumber, cars ) ->
                { lapNumber = lapNumber
                , order = cars |> List.sortBy .elapsed |> List.map .carNumber
                }
            )
