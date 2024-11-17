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
                -- 92,110 runs/s (GoF: 99.99%)
                RaceControl.init Fixture.preprocessed
            )
        , benchmark "update Add10seconds"
            (\_ ->
                -- 18,971 runs/s (GoF: 99.98%)
                RaceControl.update Add10seconds rc
            )
        , benchmark "update (SetCount 60min)"
            (\_ ->
                -- 19,193 runs/s (GoF: 99.99%)
                RaceControl.update (SetCount (60 * 60 * 1000)) rc
            )
        , benchmark "update NextLap"
            (\_ ->
                -- 18,577 runs/s (GoF: 99.99%)
                RaceControl.update NextLap rc
            )
        , benchmark "update PreviousLap"
            (\_ ->
                -- 19,132 runs/s (GoF: 99.99%)
                RaceControl.update PreviousLap rc
            )
        ]
