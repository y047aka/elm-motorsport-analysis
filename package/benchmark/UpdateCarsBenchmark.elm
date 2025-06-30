module UpdateCarsBenchmark exposing (main)

import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture.Json as Fixture
import Motorsport.RaceControl as RaceControl


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "RaceControl.updateCars" <|
        [ Benchmark.scale "Car count scaling"
            ([ 10
             , 50
             ]
                |> List.map (\size -> ( size, Fixture.jsonDecodedOfSize size ))
                |> List.map
                    (\( size, cars ) ->
                        ( "cars = " ++ String.fromInt size
                        , \_ ->
                            let
                                timeLimit =
                                    90000 * 100

                                clock =
                                    { elapsed = 90000 * 10 }
                            in
                            RaceControl.updateCars timeLimit clock cars
                        )
                    )
            )
        ]
