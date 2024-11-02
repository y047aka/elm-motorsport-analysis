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
                -- 275,720 runs/s (GoF: 100%)
                RaceControl.init Fixture.preprocessed
            )
        , benchmark "update Add10seconds"
            (\_ ->
                -- 56,532 runs/s (GoF: 99.99%)
                RaceControl.update Add10seconds rc
            )
        , benchmark "update (SetCount 60min)"
            (\_ ->
                -- 57,529 runs/s (GoF: 99.99%)
                RaceControl.update (SetCount (60 * 60 * 1000)) rc
            )
        , benchmark "update NextLap"
            (\_ ->
                -- 55,491 runs/s (GoF: 99.99%)
                RaceControl.update NextLap rc
            )
        , benchmark "update PreviousLap"
            (\_ ->
                -- 57,277 runs/s (GoF: 100%)
                RaceControl.update PreviousLap rc
            )
        ]
