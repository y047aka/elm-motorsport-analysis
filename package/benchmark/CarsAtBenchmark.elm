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
import Motorsport.Car as Car exposing (Car)
import Motorsport.Duration exposing (Duration)
import Motorsport.Entrant exposing (Entrant)
import Motorsport.Ordering as Ordering
import Motorsport.Race as Race exposing (Race)


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    let
        -- Indices and all, built once as the real race is.
        race =
            Race.fromEntrants Fixture.entrants
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
                                    { elapsed = floor (toFloat race.timeLimit * toFloat size / 100) }
                            in
                            race.entrants
                                |> List.map (carAt clock race)
                                |> Ordering.byRacePosition clock
                        )
                    )
            )
        ]


carAt : { elapsed : Duration } -> Race -> Entrant -> Car
carAt clock race entrant =
    Car.at
        { elapsed = clock.elapsed
        , status = Race.statusAt clock entrant.metadata.carNumber race
        }
        entrant
