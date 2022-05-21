module Data.RaceClock exposing (RaceClock, countDown, countUp, init, toString)

import Data.Duration as Duration exposing (Duration)
import Data.LapTimes exposing (Lap)


type alias RaceClock =
    { lapCount : Int
    , elapsed : Int
    , lapTimes : List (List Lap)
    }


init : List (List Lap) -> RaceClock
init lapTimes =
    { lapCount = 0
    , elapsed = 0
    , lapTimes = lapTimes
    }


countUp : RaceClock -> RaceClock
countUp c =
    let
        newCount =
            c.lapCount + 1
    in
    { c
        | lapCount = newCount
        , elapsed = elapsed_ newCount c.lapTimes
    }


countDown : RaceClock -> RaceClock
countDown c =
    if c.lapCount > 0 then
        let
            newCount =
                c.lapCount - 1
        in
        { c
            | lapCount = newCount
            , elapsed = elapsed_ newCount c.lapTimes
        }

    else
        c


elapsed_ : Int -> List (List Lap) -> Duration
elapsed_ lapCount lapTimes =
    let
        nextLap =
            lapCount + 1
    in
    lapTimes
        |> List.map
            (\laps ->
                laps
                    |> List.filterMap
                        (\{ lap, elapsed } ->
                            if nextLap == lap then
                                Just elapsed

                            else
                                Nothing
                        )
                    |> List.head
            )
        |> List.filterMap identity
        |> List.minimum
        |> Maybe.map (\elapsed -> elapsed - 1)
        |> Maybe.withDefault 0


toString : RaceClock -> String
toString =
    .elapsed >> Duration.toString
