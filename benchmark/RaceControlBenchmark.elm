module RaceControlBenchmark exposing (main)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Data.Wec.Preprocess as Preprocess_Wec
import Motorsport.RaceControl as RaceControl exposing (Msg(..))
import PreprocessBenchmark exposing (mockDecoded)


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "RaceControl"
        [ benchmark "Add10seconds"
            (\_ -> RaceControl.update Add10seconds raceControl)
        , benchmark "Subtract10seconds"
            (\_ -> RaceControl.update Subtract10seconds raceControl)
        , benchmark "SetCount 60min"
            (\_ -> RaceControl.update (SetCount (60 * 60 * 1000)) raceControl)
        , benchmark "NextLap"
            (\_ -> RaceControl.update NextLap raceControl)
        , benchmark "PreviousLap"
            (\_ -> RaceControl.update PreviousLap raceControl)
        ]


raceControl : RaceControl.Model
raceControl =
    RaceControl.init (Preprocess_Wec.preprocess mockDecoded)
