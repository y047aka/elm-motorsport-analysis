module Fixture.Benchmark exposing (main)

import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Csv.Decode as CD exposing (FieldNames(..))
import Data.Wec.Decoder as Wec
import Fixture.Csv as Fixture
import Fixture.Json.Laps as Fixture
import Json.Decode as JD


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Fixture" <|
        [ Benchmark.compare "xxxDecoded"
            "csvDecoded"
            -- 322 runs/s (GoF: 99.99%) ※426件のデータで実施
            (\_ ->
                case CD.decodeCustom { fieldSeparator = ';' } FieldNamesFromFirstRow Fixture.lapDecoder Fixture.csv of
                    Ok decoded_ ->
                        decoded_

                    Err _ ->
                        []
            )
            "jsonDecoded"
            -- 800 runs/s (GoF: 99.99%) ※426件のデータで実施
            (\_ ->
                case JD.decodeString (JD.list Wec.lapDecoder) Fixture.json of
                    Ok decoded_ ->
                        decoded_

                    Err _ ->
                        []
            )
        ]
