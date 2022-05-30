module Data.Leaderboard exposing (Leaderboard, leaderboard)

import Data.Duration exposing (Duration)
import Data.Gap as Gap exposing (Gap(..))
import Data.Lap exposing (Lap, completedLapsAt, findLastLapAt)
import Data.RaceClock exposing (RaceClock)


type alias Leaderboard =
    List
        { position : Int
        , carNumber : String
        , driver : String
        , lap : Int
        , gap : Gap
        , time : Duration
        , best : Duration
        , history : List Lap
        }


leaderboard : RaceClock -> List (List Lap) -> Leaderboard
leaderboard raceClock cars =
    let
        sortedCars =
            cars
                |> List.map
                    (\laps ->
                        let
                            lastLap =
                                findLastLapAt raceClock laps
                                    |> Maybe.withDefault { carNumber = "", driver = "", lap = 0, time = 0, best = 0, elapsed = 0 }
                        in
                        { laps = laps, lap = lastLap }
                    )
                |> List.sortWith
                    (\a b ->
                        case compare a.lap.lap b.lap.lap of
                            LT ->
                                GT

                            EQ ->
                                case compare a.lap.elapsed b.lap.elapsed of
                                    LT ->
                                        LT

                                    EQ ->
                                        EQ

                                    GT ->
                                        GT

                            GT ->
                                LT
                    )
    in
    sortedCars
        |> List.indexedMap
            (\index { laps, lap } ->
                let
                    { carNumber, driver } =
                        List.head laps
                            |> Maybe.map (\l -> { carNumber = l.carNumber, driver = l.driver })
                            |> Maybe.withDefault { carNumber = "000", driver = "" }
                in
                { position = index + 1
                , driver = driver
                , carNumber = carNumber
                , lap = lap.lap
                , gap =
                    List.head sortedCars
                        |> Maybe.map (\leader -> Gap.from leader.lap lap)
                        |> Maybe.withDefault None
                , time = lap.time
                , best = lap.best
                , history = completedLapsAt raceClock laps
                }
            )
