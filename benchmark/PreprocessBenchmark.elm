module PreprocessBenchmark exposing (main)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Csv.Decode as Decode exposing (FieldNames(..))
import Data.Wec.Decoder as Wec
import Data.Wec.Preprocess as Preprocess_Wec
import Fixture


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Decode and Preprocess"
        [ benchmark "Csv Decode"
            (\_ ->
                -- 192 runs/s (GoF: 99.92%)
                Decode.decodeCustom { fieldSeparator = ';' } FieldNamesFromFirstRow Wec.lapDecoder Fixture.csv
            )
        , benchmark "Data.Wec.Preprocess.preprocess"
            (\_ ->
                -- 98 runs/s (GoF: 100%)
                Preprocess_Wec.preprocess Fixture.csvDecoded
            )
        ]
