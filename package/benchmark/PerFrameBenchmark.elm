module PerFrameBenchmark exposing (main)

{-| What one frame of playback costs.

Every animation frame the race is read at a new elapsed time and the whole field
re-derived. Two layers do that work, and this weighs them apart:

  - `Snapshot.at` -- sampling every car at the clock, putting the field in
    running order, measuring the gaps and rating the times. All of it is the
    race's own; no view layer changes a number of it.
  - `Standings.compute` -- the same, and then a record per car for the view to
    render from.

The difference between the two is what the computed-view layer costs on top of
the race, which is the number worth having before deciding whether to keep it.

-}

import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture.Generated as Fixture
import Motorsport.BestTimes as BestTimes
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Snapshot as Snapshot
import Motorsport.ViewModel.Standings as Standings


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    let
        -- Indices and all, built once as the real race is.
        race =
            Race.fromCars Fixture.cars

        -- Halfway through, where every car has laps behind it and a lap in
        -- progress -- the frame that costs the most.
        clock =
            { elapsed =
                Instant.toDuration race.timeLimit
                    // 2
                    |> Instant.fromDuration
            }

        bestTimes =
            BestTimes.at clock race.bestTimeChanges
    in
    describe "one frame of playback"
        [ Benchmark.compare "what the view layer costs on top of the race"
            "Snapshot.at"
            (\_ -> Snapshot.at bestTimes clock race)
            "Standings.compute"
            (\_ -> Standings.compute bestTimes clock race)
        ]
