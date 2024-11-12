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
    describe "Array.Extra2" <|
        [ Benchmark.compare "find"
            "List.Extra.find"
            (\_ ->
                -- 32,161,542 runs/s (GoF: 99.91%)
                List.Extra.find (.lapNumber >> (==) 2) Fixture.csvDecoded
            )
            "Array.Extra2.find"
            (\_ ->
                -- 108,133 runs/s (GoF: 99.89%)
                Array.Extra2.find (.lapNumber >> (==) 2) Fixture.csvDecoded_array
            )
        , Benchmark.compare "find"
            "List.Extra.find"
            (\_ ->
                -- 32,161,542 runs/s (GoF: 99.91%)
                List.Extra.find (.lapNumber >> (==) 200) Fixture.csvDecoded
            )
            "Array.Extra2.find"
            (\_ ->
                -- 108,133 runs/s (GoF: 99.89%)
                Array.Extra2.find (.lapNumber >> (==) 200) Fixture.csvDecoded_array
            )
        ]
