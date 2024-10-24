module Motorsport.Clock exposing
    ( Clock, init, initWithCount, initWithElapsed
    , add, subtract, jumpToNextLap, jumpToPreviousLap
    , toString
    )

{-|

@docs Clock, init, initWithCount, initWithElapsed
@docs add, subtract, jumpToNextLap, jumpToPreviousLap
@docs toString

-}

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


initWithElapsed : Int -> List (List { a | lap : Int, elapsed : Duration }) -> Clock
initWithElapsed newElapsed lapTimes =
    { lapCount = lapAt newElapsed lapTimes
    , elapsed = newElapsed
    }


add : Int -> List (List { a | lap : Int, elapsed : Duration }) -> Clock -> Clock
add duration lapTimes c =
    let
        newElapsed =
            c.elapsed + duration
    in
    { c
        | lapCount = lapAt newElapsed lapTimes
        , elapsed = newElapsed
    }


subtract : Int -> List (List { a | lap : Int, elapsed : Duration }) -> Clock -> Clock
subtract duration lapTimes c =
    let
        newElapsed =
            c.elapsed - duration
    in
    { c
        | lapCount = lapAt newElapsed lapTimes
        , elapsed = newElapsed
    }


jumpToNextLap : List (List { a | lap : Int, elapsed : Duration }) -> Clock -> Clock
jumpToNextLap lapTimes c =
    let
        newCount =
            c.lapCount + 1
    in
    { c
        | lapCount = newCount
        , elapsed = elapsedAt newCount lapTimes
    }


jumpToPreviousLap : List (List { a | lap : Int, elapsed : Duration }) -> Clock -> Clock
jumpToPreviousLap lapTimes c =
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


lapAt : Int -> List (List { a | lap : Int, elapsed : Duration }) -> Int
lapAt elapsed lapTimes =
    lapTimes
        |> List.filterMap
            (List.Extra.findMap
                (\lap ->
                    if lap.elapsed > elapsed then
                        Just (lap.lap - 1)

                    else
                        Nothing
                )
            )
        |> List.maximum
        |> Maybe.withDefault 0


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
