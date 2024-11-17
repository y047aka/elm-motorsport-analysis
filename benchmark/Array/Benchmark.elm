module Array.Benchmark exposing (main)

import Array
import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "length" <|
        [ Benchmark.scale "List.length"
            ([ 1 -- 77,132,868 runs/s (GoF: 99.8%)
             , 10 -- 15,269,244 runs/s (GoF: 99.95%)
             , 100 -- 1,760,120 runs/s (GoF: 99.99%)
             , 1000 -- 183,538 runs/s (GoF: 99.99%)
             ]
                |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
                |> List.map (\( size, target ) -> ( toString size, \_ -> List.length target ))
            )
        , Benchmark.scale "Array.length"
            ([ 1 -- 269,380,493 runs/s (GoF: 100%)
             , 1000 -- 269,402,075 runs/s (GoF: 100%)
             ]
                |> List.map (\size -> ( size, Array.fromList (Fixture.csvDecodedOfSize size) ))
                |> List.map (\( size, target ) -> ( toString size, \_ -> Array.length target ))
            )
        , Benchmark.scale "Array.fromList >> Array.length"
            ([ 1 -- 18,101,073 runs/s (GoF: 99.99%)
             , 10 -- 14,530,005 runs/s (GoF: 99.99%)
             , 100 -- 2,532,302 runs/s (GoF: 99.99%)
             , 1000 -- 402,667 runs/s (GoF: 99.99%)
             ]
                |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
                |> List.map (\( size, target ) -> ( toString size, \_ -> (Array.fromList >> Array.length) target ))
            )
        ]


toString : Int -> String
toString n =
    "n = " ++ String.fromInt n
