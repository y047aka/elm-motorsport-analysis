module Array.Benchmark exposing (main)

import Array
import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture.Json.Laps as Fixture


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "length" <|
        [ Benchmark.scale "List.length"
            ([ 5 -- 30,822,646 runs/s (GoF: 99.9%)
             , 50 -- 3,824,299 runs/s (GoF: 99.9%)
             , 500 -- 392,379 runs/s (GoF: 99.92%)
             , 5000 -- 38,310 runs/s (GoF: 99.79%)
             ]
                |> List.map (\size -> ( size, Fixture.jsonDecodedOfSize size ))
                |> List.map (\( size, target ) -> ( toString size, \_ -> List.length target ))
            )
        , Benchmark.scale "Array.length"
            ([ 5 -- 274,508,871 runs/s (GoF: 99.61%)
             , 5000 -- 274,955,086 runs/s (GoF: 99.67%)
             ]
                |> List.map (\size -> ( size, Array.fromList (Fixture.jsonDecodedOfSize size) ))
                |> List.map (\( size, target ) -> ( toString size, \_ -> Array.length target ))
            )
        , Benchmark.scale "Array.fromList >> Array.length"
            ([ 5 -- 18,625,505 runs/s (GoF: 99.96%)
             , 50 -- 4,904,676 runs/s (GoF: 99.97%)
             , 500 -- 856,094 runs/s (GoF: 99.95%)
             , 5000 -- 84,065 runs/s (GoF: 99.79%)
             ]
                |> List.map (\size -> ( size, Fixture.jsonDecodedOfSize size ))
                |> List.map (\( size, target ) -> ( toString size, \_ -> (Array.fromList >> Array.length) target ))
            )
        ]


toString : Int -> String
toString n =
    "n = " ++ String.fromInt n
