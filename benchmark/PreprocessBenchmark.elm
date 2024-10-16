module PreprocessBenchmark exposing (main)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Csv.Decode exposing (FieldNames(..))
import Data.Wec.Preprocess as Preprocess_Wec
import MockData


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Data.Wec.Preprocess"
        [ benchmark "preprocess"
            (\_ -> Preprocess_Wec.preprocess MockData.csvDecoded)
        ]
