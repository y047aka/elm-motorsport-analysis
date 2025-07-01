module UpdateCarsBenchmark exposing (main)

import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture.Json as Fixture
import List.Extra
import Motorsport.Car exposing (Car, Status(..))
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap


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
                            updateCars timeLimit clock cars
                        )
                    )
            )
        ]



-- OLD


updateCars : Duration -> { elapsed : Duration } -> List Car -> List Car
updateCars timeLimit raceClock cars =
    cars
        |> List.map (updateWithClock { elapsed = raceClock.elapsed, timeLimit = timeLimit })
        |> List.sortWith
            (\a b ->
                Maybe.map2 (Lap.compareAt raceClock) a.currentLap b.currentLap
                    |> Maybe.withDefault EQ
            )


updateWithClock : { elapsed : Duration, timeLimit : Duration } -> Car -> Car
updateWithClock raceClock car =
    { car
        | currentLap = Lap.findCurrentLap { elapsed = raceClock.elapsed } car.laps
        , lastLap = Lap.findLastLapAt { elapsed = raceClock.elapsed } car.laps
    }
        |> (\updatedCar ->
                { updatedCar
                    | status =
                        case ( updatedCar.status, hasCompletedAllLaps raceClock updatedCar, isOnFinalLap raceClock updatedCar ) of
                            ( PreRace, _, _ ) ->
                                Racing

                            ( Racing, True, True ) ->
                                Checkered

                            ( Racing, True, False ) ->
                                Retired

                            ( Racing, False, _ ) ->
                                Racing

                            ( Checkered, _, _ ) ->
                                Checkered

                            ( Retired, _, _ ) ->
                                Retired
                }
           )


isOnFinalLap : { elapsed : Duration, timeLimit : Duration } -> Car -> Bool
isOnFinalLap raceClock car =
    let
        finishedAfterTimeLimit =
            raceClock.timeLimit <= raceClock.elapsed

        hasReachedFinalLap =
            Maybe.map2 (==) car.currentLap (List.Extra.last car.laps)
                |> Maybe.withDefault False
    in
    hasReachedFinalLap && finishedAfterTimeLimit


hasCompletedAllLaps : { a | elapsed : Duration } -> Car -> Bool
hasCompletedAllLaps raceClock car =
    List.Extra.last car.laps
        |> Maybe.map (\finalLap -> finalLap.elapsed <= raceClock.elapsed)
        |> Maybe.withDefault False
