module Fixture.Benchmark exposing (main)

import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Fixture" <|
        [ Benchmark.scale "csvDecodedOfSize"
            ([ 5 -- 80,891,064 runs/s (GoF: 99.96%)
             , 50 -- 7,883,407 runs/s (GoF: 99.93%)
             , 500 -- 72,204 runs/s (GoF: 99.9%)
             , 5000 -- 25,161 runs/s (GoF: 99.92%)
             ]
                |> List.map (\size -> ( toString size, \_ -> Fixture.csvDecodedOfSize size ))
            )
        ]


toString : Int -> String
toString n =
    "n = " ++ String.fromInt n
