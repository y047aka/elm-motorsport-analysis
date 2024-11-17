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
            ([ 2 -- 19,662,511 runs/s (GoF: 99.95%)
             , 20 -- 2,889,796 runs/s (GoF: 99.91%)
             , 200 -- 309,931 runs/s (GoF: 99.94%)
             ]
                |> List.map (\n -> ( toString n, \_ -> List.Extra.find (.lapNumber >> (==) n) Fixture.csvDecoded ))
            )
        , Benchmark.scale "Array.Extra2.find"
            ([ 2 -- 104,597 runs/s (GoF: 99.96%)
             , 20 -- 102,423 runs/s (GoF: 99.95%)
             , 200 -- 84,687 runs/s (GoF: 99.95%)
             ]
                |> List.map (\n -> ( toString n, \_ -> Array.Extra2.find (.lapNumber >> (==) n) Fixture.csvDecoded_array ))
            )
        ]


toString : Int -> String
toString n =
    "n = " ++ String.fromInt n
