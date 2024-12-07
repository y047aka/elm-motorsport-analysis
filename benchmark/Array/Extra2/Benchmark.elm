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
            ([ 5 -- 37,757,037 runs/s (GoF: 99.98%)
             , 50 -- 4,935,546 runs/s (GoF: 100%)
             , 500 -- 53,338 runs/s (GoF: 99.98%)
             , 5000 -- 53,221 runs/s (GoF: 99.98%)
             ]
                |> List.map (\n -> ( toString n, \_ -> List.Extra.find (\{ lapNumber } -> lapNumber == n) Fixture.csvDecoded ))
            )
        , Benchmark.scale "再帰とfindHelp による末尾最適化の組み合わせ"
            ([ 5 -- 8,159,839 runs/s (GoF: 99.93%)
             , 50 -- 950,765 runs/s (GoF: 99.86%)
             , 500 -- 9,608 runs/s (GoF: 99.85%)
             , 5000 -- 9,627 runs/s (GoF: 99.87%)
             ]
                |> List.map (\n -> ( toString n, \_ -> Array.Extra2.find (\{ lapNumber } -> lapNumber == n) Fixture.csvDecoded_array ))
            )
        , Benchmark.scale "Array.foldl を使う場合（deprecated）"
            ([ 5 -- 12,909 runs/s (GoF: 99.94%)
             , 50 -- 12,915 runs/s (GoF: 99.95%)
             , 500 -- 14,976 runs/s (GoF: 99.96%)
             , 5000 -- 15,021 runs/s (GoF: 99.97%)
             ]
                |> List.map (\n -> ( toString n, \_ -> find_old (\{ lapNumber } -> lapNumber == n) Fixture.csvDecoded_array ))
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
