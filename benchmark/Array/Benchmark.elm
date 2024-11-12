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
    describe "Array" <|
        [  Benchmark.compare "length"
            "List.length"
            (\_ ->
                -- 296,394 runs/s (GoF: 99.99%)
                List.length Fixture.csvDecoded
            )
            "Array.length"
            (\_ ->
                -- 290,366,954 runs/s (GoF: 99.99%)
                Array.length Fixture.csvDecoded_array
            )
        , Benchmark.compare "fromList >> length"
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
