module UpdateCarsBenchmark exposing (main)

import Benchmark exposing (Benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Fixture.Json as Fixture
import List.Extra
import Motorsport.Car exposing (Car, Status(..))
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap as Lap
import Motorsport.RaceControl as RaceControl


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
        [ Benchmark.scale "old"
            ([ 25 -- 5,338
             , 50 -- 5,282
             , 75 -- 5,186
             ]
                |> List.map
                    (\size ->
                        ( String.fromInt size ++ "%"
                        , \_ ->
                            let
                                clock =
                                    { elapsed = floor (toFloat timeLimit * toFloat size / 100) }
                            in
                            updateCars timeLimit clock cars
                        )
                    )
            )
        , Benchmark.scale "new"
            ([ 25 -- 949
             , 50 -- 413
             , 75 -- 263
             ]
                |> List.map (\size -> ( size, RaceControl.calcEvents timeLimit cars ))
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



-- HELPERS


calcTimeLimit : List Car -> Duration
calcTimeLimit =
    List.map (.laps >> List.Extra.last >> Maybe.map .elapsed)
        >> List.filterMap identity
        >> List.maximum
        >> Maybe.map (\timeLimit -> (timeLimit // (60 * 60 * 1000)) * 60 * 60 * 1000)
        >> Maybe.withDefault 0
