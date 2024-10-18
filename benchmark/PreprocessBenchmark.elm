module PreprocessBenchmark exposing (main)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Csv.Decode exposing (FieldNames(..))
import Data.Wec.Preprocess as Preprocess_Wec
import Fixture


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Data.Wec.Preprocess"
        [ benchmark "preprocess"
            (\_ ->
                -- 98 runs/s (GoF: 100%)
                Preprocess_Wec.preprocess Fixture.csvDecoded
            )
        ]
