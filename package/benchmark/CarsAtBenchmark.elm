module CarsAtBenchmark exposing (main)

{-| The per-frame cost of the computed-model layer: read every entrant at an
elapsed time, then put the results into running order.

This replaces a benchmark that weighed two ways of accumulating a car's status
against each other. Both are gone -- the status now comes from a precomputed
index -- so what is worth measuring is the derivation itself.

-}

import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture.Generated as Fixture
import List.Extra
import Motorsport.Car as Car exposing (Car)
import Motorsport.Car.StatusIndex as StatusIndex exposing (StatusIndex)
import Motorsport.Duration exposing (Duration)
import Motorsport.Entrant exposing (Entrant)
import Motorsport.Ordering as Ordering
import Motorsport.TimelineEvent as TimelineEvent


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    let
        entrants =
            Fixture.entrants

        timeLimit =
            calcTimeLimit entrants

        -- Built once when the race loads, as the real one is.
        statusIndex =
            StatusIndex.fromTimelineEvents (TimelineEvent.fromEntrants entrants)
    in
    describe "cars at an elapsed time" <|
        [ Benchmark.scale "derive + running order"
            ([ 25
             , 50
             , 75
             ]
                |> List.map
                    (\size ->
                        ( String.fromInt size ++ "%"
                        , \_ ->
                            let
                                clock =
                                    { elapsed = floor (toFloat timeLimit * toFloat size / 100) }
                            in
                            entrants
                                |> List.map (carAt clock statusIndex)
                                |> Ordering.byRacePosition clock
                        )
                    )
            )
        ]


carAt : { elapsed : Duration } -> StatusIndex -> Entrant -> Car
carAt clock statusIndex entrant =
    Car.at
        { elapsed = clock.elapsed
        , status = StatusIndex.statusAt clock entrant.metadata.carNumber statusIndex
        }
        entrant


calcTimeLimit : List Entrant -> Duration
calcTimeLimit =
    List.map (.laps >> List.Extra.last >> Maybe.map .elapsed)
        >> List.filterMap identity
        >> List.maximum
        >> Maybe.map (\timeLimit -> (timeLimit // (60 * 60 * 1000)) * 60 * 60 * 1000)
        >> Maybe.withDefault 0
