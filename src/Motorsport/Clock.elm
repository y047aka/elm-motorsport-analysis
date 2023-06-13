module Motorsport.Clock exposing (Clock, countDown, countUp, init, initWithCount, toString)

import List.Extra
import Motorsport.Duration as Duration exposing (Duration)


type alias Clock =
    { lapCount : Int, elapsed : Duration }


init : Clock
init =
    { lapCount = 0, elapsed = 0 }


initWithCount : Int -> List (List { a | lap : Int, elapsed : Duration }) -> Clock
initWithCount newCount lapTimes =
    { lapCount = newCount
    , elapsed = elapsedAt newCount lapTimes
    }


countUp : List (List { a | lap : Int, elapsed : Duration }) -> Clock -> Clock
countUp lapTimes c =
    let
        newCount =
            c.lapCount + 1
    in
    { c
        | lapCount = newCount
        , elapsed = elapsedAt newCount lapTimes
    }


countDown : List (List { a | lap : Int, elapsed : Duration }) -> Clock -> Clock
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


toString : Clock -> String
toString =
    .elapsed >> Duration.toString
