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
            ([ 5 -- 9,524,184 runs/s (GoF: 99.97%)
             , 50 -- 1,193,032 runs/s (GoF: 99.99%)
             , 500 -- 12,420 runs/s (GoF: 100%)
             , 5000 -- 12,435 runs/s (GoF: 100%)
             ]
                |> List.map (\n -> ( toString n, \_ -> List.Extra.find (.lapNumber >> (==) n) Fixture.csvDecoded ))
            )
        , Benchmark.scale "再帰とfindHelp による末尾最適化の組み合わせ"
            ([ 5 -- 5,042,456 runs/s (GoF: 99.98%)
             , 50 -- 580,771 runs/s (GoF: 99.99%)
             , 500 -- 5,898 runs/s (GoF: 99.99%)
             , 5000 -- 5,905 runs/s (GoF: 100%)
             ]
                |> List.map (\n -> ( toString n, \_ -> Array.Extra2.find (.lapNumber >> (==) n) Fixture.csvDecoded_array ))
            )
        , Benchmark.scale "Array.foldl を使う場合（deprecated）"
            ([ 5 -- 7,149 runs/s (GoF: 99.98%)
             , 50 -- 7,172 runs/s (GoF: 99.97%)
             , 500 -- 7,514 runs/s (GoF: 99.97%)
             , 5000 -- 7,548 runs/s (GoF: 99.96%)
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
