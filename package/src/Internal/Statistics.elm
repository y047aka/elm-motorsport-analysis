module Internal.Statistics exposing
    ( iqrFences, upperFence, upperFenceBy
    , median, quantile
    )

{-| The plain statistics a reading of the race is taken with: the outlier
fences a chart bounds itself by, and the middle of a set of values.

@docs iqrFences, upperFence, upperFenceBy
@docs median, quantile

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


{-| Upper outlier fence `Q3 + 1.5×IQR`. Falls back to the maximum when there are
too few values to compute a fence (0 for an empty list). Input need not be
sorted.

    upperFence [ 1, 2, 3, 4, 5, 6, 7, 8 ]
    --> 12

    upperFence [ 1, 2, 3 ]
    --> 3

-}
upperFence : List Int -> Int
upperFence =
    upperFenceBy 1.5


{-| Upper outlier fence `Q3 + k×IQR`, for a chart that wants the outlier cut
tighter or looser than the classic `1.5`.

    upperFenceBy 0.5 [ 1, 2, 3, 4, 5, 6, 7, 8 ]
    --> 8

-}
upperFenceBy : Float -> List Int -> Int
upperFenceBy k values =
    let
        sorted =
            List.sort values
    in
    -- Four is where nearest-rank quartiles stop collapsing: below it `Q3` is
    -- drawn from the lower half of the set, so the fence lands on or under the
    -- smallest value and rules out everything above it -- [ 100, 101 ] fences at
    -- 100. Below four the maximum is the only honest upper bound.
    case
        if List.length sorted < 4 then
            Nothing

        else
            Maybe.map2 Tuple.pair (quantile 0.25 sorted) (quantile 0.75 sorted)
    of
        Just ( q1, q3 ) ->
            q3 + round (k * toFloat (q3 - q1))

        Nothing ->
            List.maximum sorted |> Maybe.withDefault 0


{-| The middle value, by nearest rank -- for an even count the lower of the two
middles rather than the mean of them, so what comes back is always one of the
values given.

    median [ 3, 1, 2 ]
    --> Just 2

    median [ 1, 2, 3, 4 ]
    --> Just 2

-}
median : List Int -> Maybe Int
median =
    List.sort >> quantile 0.5


{-| The q-quantile (0–1) of an ascending-sorted list, by lower rank: the
largest element at or below `q` of the span, so the example below is the
second of three, not the third. `median` is this at 0.5. A forecast built on
this estimator moves if the estimator does -- see `Motorsport.Analysis.Strategy`.

    quantile 0.9 [ 1, 2, 3 ]
    --> Just 2

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
