module ArrayBenchmark exposing (main)

import Array
import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "length" <|
        [ benchmark "List.length"
            (\_ ->
                -- 295,670 runs/s (GoF: 99.98%)
                List.length Fixture.csvDecoded
            )
        , let
            csvDecoded_array =
                Array.fromList Fixture.csvDecoded
          in
          Benchmark.compare "Array.length"
            "List.length"
            (\_ ->
                -- 296,394 runs/s (GoF: 99.99%)
                List.length Fixture.csvDecoded
            )
            "Array.length"
            (\_ ->
                -- 290,366,954 runs/s (GoF: 99.99%)
                Array.length csvDecoded_array
            )
        , Benchmark.compare "Array.fromList >> Array.length"
            "List.length"
            (\_ ->
                -- 296,512 runs/s (GoF: 99.98%)
                List.length Fixture.csvDecoded
            )
            "Array.length"
            (\_ ->
                -- 644,729 runs/s (GoF: 99.99%)
                (Array.fromList >> Array.length) Fixture.csvDecoded
            )
        ]
