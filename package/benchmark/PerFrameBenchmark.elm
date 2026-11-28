module PerFrameBenchmark exposing (main)

{-| What one frame of playback costs.

Every animation frame the race is read at a new elapsed time and the whole field
re-derived: sampling every car at the clock, putting the field in running order,
measuring the gaps, rating the times. `Snapshot.at` is all of that, and every
view of the frame reads the one result.

Half distance is the frame that costs the most -- every car has laps behind it
and a lap in progress.

-}

import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture.Generated as Fixture
import Motorsport.Instant as Instant
import Motorsport.Race.Snapshot as Snapshot


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    let
        clock =
            { elapsed =
                Instant.toDuration Fixture.race.timeLimit
                    // 2
                    |> Instant.fromDuration
            }
    in
    describe "one frame of playback"
        [ Benchmark.benchmark "Snapshot.at" (\_ -> Snapshot.at clock Fixture.race)
        ]
