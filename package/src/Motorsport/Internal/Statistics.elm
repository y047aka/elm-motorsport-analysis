module Motorsport.Internal.Statistics exposing (iqrFences, upperFence)

{-| The outlier statistics the charts bound themselves by.

Nothing here knows anything about a race. A lap behind a safety car and a lap
spent in the pits are outliers by the same arithmetic as any other sample, and
what counts as one is a question about the numbers rather than about the cars --
which is why this sits beside the other machinery rather than with the race's
own vocabulary.

@docs iqrFences, upperFence

-}


{-| IQR outlier fences `[Q1 − 1.5×IQR, Q3 + 1.5×IQR]` for an ascending-sorted
list. `Nothing` when empty.

    iqrFences [ 1, 2, 3, 4, 5, 6, 7, 8 ]
    --> Just { lower = -4, upper = 12 }

-}
iqrFences : List Int -> Maybe { lower : Int, upper : Int }
iqrFences sorted =
    Maybe.map2
        (\q1 q3 ->
            let
                margin =
                    round (1.5 * toFloat (q3 - q1))
            in
            { lower = q1 - margin, upper = q3 + margin }
        )
        (quantile 0.25 sorted)
        (quantile 0.75 sorted)


{-| Upper outlier fence `Q3 + 1.5×IQR`, used as the upper bound of the racing
band. Falls back to the maximum when there are too few values to compute a fence
(0 for an empty list). Input need not be sorted.

    upperFence [ 1, 2, 3, 4, 5, 6, 7, 8 ]
    --> 12

-}
upperFence : List Int -> Int
upperFence values =
    iqrFences (List.sort values)
        |> Maybe.map .upper
        |> Maybe.withDefault (List.maximum values |> Maybe.withDefault 0)


{-| The q-quantile (0–1) of an ascending-sorted list, by nearest rank.
-}
quantile : Float -> List Int -> Maybe Int
quantile q sorted =
    let
        n =
            List.length sorted
    in
    if n == 0 then
        Nothing

    else
        let
            idx =
                clamp 0 (n - 1) (floor (toFloat (n - 1) * q))
        in
        sorted |> List.drop idx |> List.head
