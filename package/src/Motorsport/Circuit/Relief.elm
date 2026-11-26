module Motorsport.Circuit.Relief exposing
    ( Relief, fromHeights
    , lap, pitLane, at, lowest, highest
    )

{-| How high a circuit stands along its lap and its pit lane, above the datum
its heights were sampled against.

A height is held at each point the drawing is made of, beside how far round the lap the
point stands; between two points the line is straight, so a height between them is the
one the straight line passes.

@docs Relief, fromHeights
@docs lap, pitLane, at, lowest, highest

-}

import Array exposing (Array)
import Length exposing (Length)
import Quantity


type Relief
    = Relief
        { lap : Array { metres : Length, height : Length }
        , pitLane : List Length
        , lowest : Length
        , highest : Length
        }


{-| The heights of the lap's points, in the order the lap is driven and each beside its
metre, and of the pit lane's points in the order it is drawn.
-}
fromHeights : { lap : List { metres : Length, height : Length }, pitLane : List Length } -> Relief
fromHeights heights =
    let
        all =
            List.map .height heights.lap ++ heights.pitLane
    in
    Relief
        { lap = Array.fromList heights.lap
        , pitLane = heights.pitLane
        , lowest = Maybe.withDefault Quantity.zero (Quantity.minimum all)
        , highest = Maybe.withDefault Quantity.zero (Quantity.maximum all)
        }


{-| The lap's heights, one per point of its line.
-}
lap : Relief -> List Length
lap (Relief relief) =
    Array.toList relief.lap |> List.map .height


{-| The pit lane's heights, one per point of its line.
-}
pitLane : Relief -> List Length
pitLane (Relief relief) =
    relief.pitLane


{-| The lowest and the highest of either line's heights.
-}
lowest : Relief -> Length
lowest (Relief relief) =
    relief.lowest


highest : Relief -> Length
highest (Relief relief) =
    relief.highest


{-| How high the lap stands `metres` round it. A distance past the end of the lap, or
short of its start, is taken round the lap again.

    import Length exposing (meters)

    hill : Relief
    hill =
        fromHeights
            { lap =
                [ { metres = meters 0, height = meters 150 }
                , { metres = meters 100, height = meters 160 }
                , { metres = meters 200, height = meters 150 }
                ]
            , pitLane = []
            }

    at (meters 50) hill
    --> meters 155

    at (meters 250) hill
    --> meters 155

-}
at : Length -> Relief -> Length
at metres (Relief relief) =
    let
        length =
            Array.get (Array.length relief.lap - 1) relief.lap
                |> Maybe.map .metres
                |> Maybe.withDefault Quantity.zero

        wrapped =
            if Quantity.greaterThanZero length then
                let
                    laps =
                        Quantity.float (toFloat (floor (Quantity.ratio metres length)))
                in
                Quantity.difference metres (Quantity.timesUnitless laps length)

            else
                Quantity.zero

        i =
            lastAtOrBefore wrapped relief.lap 0 (Array.length relief.lap - 1)
    in
    case ( Array.get i relief.lap, Array.get (i + 1) relief.lap ) of
        ( Just a, Just b ) ->
            if b.metres |> Quantity.greaterThan a.metres then
                let
                    share =
                        Quantity.ratio (Quantity.difference wrapped a.metres) (Quantity.difference b.metres a.metres)
                in
                Quantity.plus a.height (Quantity.timesUnitless (Quantity.float share) (Quantity.difference b.height a.height))

            else
                a.height

        ( Just a, Nothing ) ->
            a.height

        ( Nothing, _ ) ->
            Quantity.zero


lastAtOrBefore : Length -> Array { metres : Length, height : Length } -> Int -> Int -> Int
lastAtOrBefore metres array lo hi =
    if hi - lo <= 1 then
        lo

    else
        let
            mid =
                (lo + hi) // 2
        in
        case Array.get mid array of
            Just mark ->
                if mark.metres |> Quantity.lessThanOrEqualTo metres then
                    lastAtOrBefore metres array mid hi

                else
                    lastAtOrBefore metres array lo mid

            Nothing ->
                lo
