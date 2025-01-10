module Array.Extra2.Benchmark exposing (main)

import Array.Extra2
import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture.Json.Laps as Fixture
import List.Extra


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "find" <|
        [ Benchmark.scale "List.Extra.find"
            ([ 5 -- 37,757,037 runs/s (GoF: 99.98%)
             , 50 -- 4,935,546 runs/s (GoF: 100%)
             , 500 -- 53,338 runs/s (GoF: 99.98%)
             , 5000 -- 53,221 runs/s (GoF: 99.98%)
             ]
                |> List.map (\n -> ( toString n, \_ -> List.Extra.find (\{ lapNumber } -> lapNumber == n) Fixture.jsonDecoded ))
            )
        , Benchmark.scale "Array.Extra2.find"
            ([ 5 -- 7,403,845 runs/s (GoF: 99.95%)
             , 50 -- 855,054 runs/s (GoF: 99.9%)
             , 500 -- 8,788 runs/s (GoF: 99.99%)
             , 5000 -- 8,795 runs/s (GoF: 99.99%)
             ]
                |> List.map (\n -> ( toString n, \_ -> Array.Extra2.find (\{ lapNumber } -> lapNumber == n) Fixture.jsonDecoded_array ))
            )
        ]


toString : Int -> String
toString n =
    "n = " ++ String.fromInt n
