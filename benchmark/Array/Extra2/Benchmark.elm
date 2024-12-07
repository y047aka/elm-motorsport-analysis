module Array.Extra2.Benchmark exposing (main)

import Array exposing (Array)
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
    describe "find" <|
        [ Benchmark.scale "List.Extra.find"
            ([ 5 -- 12,713,814 runs/s (GoF: 99.92%)
             , 50 -- 1,617,212 runs/s (GoF: 99.84%)
             , 500 -- 17,169 runs/s (GoF: 99.79%)
             , 5000 -- 17,176 runs/s (GoF: 99.77%)
             ]
                |> List.map (\n -> ( toString n, \_ -> List.Extra.find (.lapNumber >> (==) n) Fixture.csvDecoded ))
            )
        , Benchmark.scale "再帰とfindHelp による末尾最適化の組み合わせ"
            ([ 5 -- 6,396,616 runs/s (GoF: 99.95%)
             , 50 -- 755,237 runs/s (GoF: 99.93%)
             , 500 -- 7,789 runs/s (GoF: 99.96%)
             , 5000 -- 7,786 runs/s (GoF: 99.97%)
             ]
                |> List.map (\n -> ( toString n, \_ -> Array.Extra2.find (.lapNumber >> (==) n) Fixture.csvDecoded_array ))
            )
        , Benchmark.scale "Array.foldl を使う場合（deprecated）"
            ([ 5 -- 14,963 runs/s (GoF: 99.95%)
             , 50 -- 14,938 runs/s (GoF: 99.92%)
             , 500 -- 10,099 runs/s (GoF: 99.82%)
             , 5000 -- 10,114 runs/s (GoF: 99.88%)
             ]
                |> List.map (\n -> ( toString n, \_ -> find_old (.lapNumber >> (==) n) Fixture.csvDecoded_array ))
            )
        ]


toString : Int -> String
toString n =
    "n = " ++ String.fromInt n


find_old : (a -> Bool) -> Array a -> Maybe a
find_old predicate array =
    Array.foldl
        (\item acc ->
            if acc == Nothing && predicate item then
                Just item

            else
                acc
        )
        Nothing
        array
