module RaceControlBenchmark exposing (main)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Data.Wec.Preprocess as Preprocess_Wec
import MockData
import Motorsport.Car exposing (Car)
import Motorsport.RaceControl as RaceControl exposing (Msg(..))


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    let
        rc =
            RaceControl.init preprocessed
    in
    describe "RaceControl"
        [ benchmark "init"
            (\_ -> RaceControl.init preprocessed)
        , benchmark "update Add10seconds"
            (\_ -> RaceControl.update Add10seconds rc)
        , benchmark "update Subtract10seconds"
            (\_ -> RaceControl.update Subtract10seconds rc)
        , benchmark "update (SetCount 60min)"
            (\_ -> RaceControl.update (SetCount (60 * 60 * 1000)) rc)
        , benchmark "update NextLap"
            (\_ -> RaceControl.update NextLap rc)
        , benchmark "update PreviousLap"
            (\_ -> RaceControl.update PreviousLap rc)
        ]


preprocessed : List Car
preprocessed =
    Preprocess_Wec.preprocess MockData.csvDecoded
