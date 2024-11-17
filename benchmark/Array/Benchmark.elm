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
            ([ 0 -- 108,239,200 runs/s (GoF: 99.84%)
             , 100 -- 1,754,214 runs/s (GoF: 99.99%)
             , 500 -- 367,023 runs/s (GoF: 99.99%)
             ]
                |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
                |> List.map (\( size, target ) -> ( toString size, \_ -> List.length target ))
            )
        , Benchmark.scale "Array.length"
            ([ 0 -- 269,282,707 runs/s (GoF: 99.99%)
             , 500 -- 269,150,399 runs/s (GoF: 99.99%)
             ]
                |> List.map (\size -> ( size, Array.fromList (Fixture.csvDecodedOfSize size) ))
                |> List.map (\( size, target ) -> ( toString size, \_ -> Array.length target ))
            )
        , Benchmark.scale "Array.fromList >> Array.length"
            ([ 0 -- 41,046,798 runs/s (GoF: 99.98%)
             , 100 -- 2,625,093 runs/s (GoF: 99.99%)
             , 500 -- 780,566 runs/s (GoF: 100%)
             ]
                |> List.map (\size -> ( size, Fixture.csvDecodedOfSize size ))
                |> List.map (\( size, target ) -> ( toString size, \_ -> (Array.fromList >> Array.length) target ))
            )
        ]


toString : Int -> String
toString n =
    "n = " ++ String.fromInt n
