module RaceControlBenchmark exposing (main)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture
import Motorsport.RaceControl as RaceControl exposing (Msg(..))


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    let
        rc =
            RaceControl.init Fixture.preprocessed
    in
    describe "RaceControl"
        [ benchmark "init"
            (\_ ->
                -- 262,541 runs/s (GoF: 99.99%)
                RaceControl.init Fixture.preprocessed
            )
        , benchmark "update Add10seconds"
            (\_ ->
                -- 55,202 runs/s (GoF: 99.98%)
                RaceControl.update Add10seconds rc
            )
        , benchmark "update Subtract10seconds"
            (\_ ->
                -- 55,065 runs/s (GoF: 99.95%)
                RaceControl.update Subtract10seconds rc
            )
        , benchmark "update (SetCount 60min)"
            (\_ ->
                -- 55,250 runs/s (GoF: 99.98%)
                RaceControl.update (SetCount (60 * 60 * 1000)) rc
            )
        , benchmark "update NextLap"
            (\_ ->
                -- 54,822 runs/s (GoF: 99.97%)
                RaceControl.update NextLap rc
            )
        , benchmark "update PreviousLap"
            (\_ ->
                -- 54,678 runs/s (GoF: 99.93%)
                RaceControl.update PreviousLap rc
            )
        ]
