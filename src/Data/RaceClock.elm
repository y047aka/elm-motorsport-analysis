module Data.RaceClock exposing (RaceClock, countDown, countUp, init, toString)

import Data.Duration as Duration exposing (Duration)
import List.Extra


type alias RaceClock =
    { lapCount : Int, elapsed : Duration }


init : RaceClock
init =
    { lapCount = 0, elapsed = 0 }


countUp : List (List { a | lap : Int, elapsed : Duration }) -> RaceClock -> RaceClock
countUp lapTimes c =
    let
        newCount =
            c.lapCount + 1
    in
    { c
        | lapCount = newCount
        , elapsed = elapsedAt newCount lapTimes
    }


countDown : List (List { a | lap : Int, elapsed : Duration }) -> RaceClock -> RaceClock
countDown lapTimes c =
    if c.lapCount > 0 then
        let
            newCount =
                c.lapCount - 1
        in
        { c
            | lapCount = newCount
            , elapsed = elapsedAt newCount lapTimes
        }

    else
        c


elapsedAt : Int -> List (List { a | lap : Int, elapsed : Duration }) -> Duration
elapsedAt lapCount lapTimes =
    let
        nextLap =
            lapCount + 1
    in
    lapTimes
        |> List.filterMap
            (List.Extra.findMap
                (\{ lap, elapsed } ->
                    if nextLap == lap then
                        Just elapsed

                    else
                        Nothing
                )
            )
        |> List.minimum
        |> Maybe.map (\elapsed -> elapsed - 1)
        |> Maybe.withDefault 0


toString : RaceClock -> String
toString =
    .elapsed >> Duration.toString
