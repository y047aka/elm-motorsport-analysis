module Data.RaceClock exposing (RaceClock, countDown, countUp, init, toString)

import Data.LapTime as LapTime exposing (LapTime)
import Data.LapTimes exposing (Lap)


type alias RaceClock =
    { lapCount : Int
    , time : Int
    , lapTimes : List (List Lap)
    }


init : List (List Lap) -> RaceClock
init lapTimes =
    { lapCount = 0
    , time = 0
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
        , time = time newCount c.lapTimes
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
            , time = time newCount c.lapTimes
        }

    else
        c


time : Int -> List (List Lap) -> LapTime
time lapCount lapTimes =
    lapTimes
        |> List.map
            (\laps ->
                laps
                    |> List.filterMap
                        (\{ lap, elapsed } ->
                            if lapCount == lap then
                                Just elapsed

                            else
                                Nothing
                        )
                    |> List.head
                    |> Maybe.withDefault 0
            )
        |> List.minimum
        |> Maybe.withDefault 0


toString : RaceClock -> String
toString =
    .time >> LapTime.toString
