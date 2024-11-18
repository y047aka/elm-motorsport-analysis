module Preprocess.Benchmark exposing (main)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Data.Wec.Preprocess as Preprocess_Wec
import Fixture


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Preprocess"
        [ benchmark "Data.Wec.Preprocess.preprocess"
            (\_ ->
                -- 32 runs/s (GoF: 99.99%)
                Preprocess_Wec.preprocess Fixture.csvDecoded
            )
        ]
