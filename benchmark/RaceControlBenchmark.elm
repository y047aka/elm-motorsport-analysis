module RaceControlBenchmark exposing (main)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture.Csv as Fixture
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
                -- 37,171 runs/s (GoF: 99.96%)
                RaceControl.init Fixture.preprocessed
            )
        , benchmark "update Add10seconds"
            (\_ ->
                -- 7,218 runs/s (GoF: 99.88%)
                RaceControl.update Add10seconds rc
            )
        , benchmark "update (SetCount 60min)"
            (\_ ->
                -- 7,332 runs/s (GoF: 99.97%)
                RaceControl.update (SetCount (60 * 60 * 1000)) rc
            )
        , benchmark "update NextLap"
            (\_ ->
                -- 6,977 runs/s (GoF: 99.86%)
                RaceControl.update NextLap rc
            )
        , benchmark "update PreviousLap"
            (\_ ->
                -- 7,264 runs/s (GoF: 99.85%)
                RaceControl.update PreviousLap rc
            )
        ]
