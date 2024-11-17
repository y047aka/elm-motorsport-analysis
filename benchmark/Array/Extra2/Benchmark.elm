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
            ([ 1 -- 26,782,994 runs/s (GoF: 99.96%)
             , 10 -- 5,211,758 runs/s (GoF: 99.93%)
             , 100 -- 601,940 runs/s (GoF: 99.92%)
             , 1000 -- 33,614 runs/s (GoF: 99.96%)
             ]
                |> List.map (\n -> ( toString n, \_ -> List.Extra.find (.lapNumber >> (==) n) Fixture.csvDecoded ))
            )
        , Benchmark.scale "Array.Extra2.find"
            ([ 1 -- 35,143 runs/s (GoF: 99.95%)
             , 10 -- 34,960 runs/s (GoF: 99.94%)
             , 100 -- 33,680 runs/s (GoF: 99.95%)
             , 1000 -- 20,287 runs/s (GoF: 99.92%)
             ]
                |> List.map (\n -> ( toString n, \_ -> Array.Extra2.find (.lapNumber >> (==) n) Fixture.csvDecoded_array ))
            )
        ]


toString : Int -> String
toString n =
    "n = " ++ String.fromInt n
