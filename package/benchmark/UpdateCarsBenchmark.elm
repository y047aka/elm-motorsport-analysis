module UpdateCarsBenchmark exposing (main)

import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture.Json as Fixture
import List.Extra
import Motorsport.Car exposing (Car)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Motorsport.RaceControl as RaceControl
import Motorsport.TimelineEvent as TimelineEvent


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    let
        cars =
            Fixture.jsonDecoded

        timeLimit =
            calcTimeLimit cars
    in
    describe "RaceControl.updateCars" <|
        [ Benchmark.scale "new"
            ([ 25 -- 10,812
             , 50 -- 10,994
             , 75 -- 12,744
             ]
                |> List.map (\size -> ( size, TimelineEvent.fromCars cars ))
                |> List.map
                    (\( size, events ) ->
                        ( String.fromInt size ++ "%"
                        , \_ ->
                            let
                                clock =
                                    { elapsed = floor (toFloat timeLimit * toFloat size / 100) }
                            in
                            cars
                                |> RaceControl.applyEvents clock.elapsed events
                                |> List.sortWith
                                    (\a b ->
                                        Maybe.map2 (Lap.compareAt clock) a.currentLap b.currentLap
                                            |> Maybe.withDefault EQ
                                    )
                        )
                    )
            )
        ]



-- HELPERS


calcTimeLimit : List Car -> Duration
calcTimeLimit =
    List.map (.laps >> List.Extra.last >> Maybe.map .elapsed)
        >> List.filterMap identity
        >> List.maximum
        >> Maybe.map (\timeLimit -> (timeLimit // (60 * 60 * 1000)) * 60 * 60 * 1000)
        >> Maybe.withDefault 0
