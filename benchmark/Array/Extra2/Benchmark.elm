module Array.Extra2.Benchmark exposing (main)

import Array.Extra2
import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture
import List.Extra


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Array.Extra2.find" <|
        [ Benchmark.scale "List.Extra.find"
            ([ 5 -- 12,713,814 runs/s (GoF: 99.92%)
             , 50 -- 1,617,212 runs/s (GoF: 99.84%)
             , 500 -- 17,169 runs/s (GoF: 99.79%)
             , 5000 -- 17,176 runs/s (GoF: 99.77%)
             ]
                |> List.map (\n -> ( toString n, \_ -> List.Extra.find (.lapNumber >> (==) n) Fixture.csvDecoded ))
            )
        , Benchmark.scale "Array.Extra2.find"
            ([ 5 -- 14,963 runs/s (GoF: 99.95%)
             , 50 -- 14,938 runs/s (GoF: 99.92%)
             , 500 -- 10,099 runs/s (GoF: 99.82%)
             , 5000 -- 10,114 runs/s (GoF: 99.88%)
             ]
                |> List.map (\n -> ( toString n, \_ -> Array.Extra2.find (.lapNumber >> (==) n) Fixture.csvDecoded_array ))
            )
        ]


toString : Int -> String
toString n =
    "n = " ++ String.fromInt n
