module Motorsport.Circuit.Relief exposing
    ( Relief, fromHeights
    , lap, pitLane, at, lowest, highest
    )

{-| How high a circuit stands along its lap and its pit lane, in metres above the datum
its heights were sampled against.

A height is held at each point the drawing is made of, beside how far round the lap the
point stands; between two points the line is straight, so a height between them is the
one the straight line passes.

@docs Relief, fromHeights
@docs lap, pitLane, at, lowest, highest

-}

import Array exposing (Array)


type Relief
    = Relief
        { lap : Array { metres : Float, height : Float }
        , pitLane : List Float
        , lowest : Float
        , highest : Float
        }


{-| The heights of the lap's points, in the order the lap is driven and each beside its
metre, and of the pit lane's points in the order it is drawn.
-}
fromHeights : { lap : List { metres : Float, height : Float }, pitLane : List Float } -> Relief
fromHeights heights =
    let
        all =
            List.map .height heights.lap ++ heights.pitLane
    in
    Relief
        { lap = Array.fromList heights.lap
        , pitLane = heights.pitLane
        , lowest = Maybe.withDefault 0 (List.minimum all)
        , highest = Maybe.withDefault 0 (List.maximum all)
        }


{-| The lap's heights, one per point of its line.
-}
lap : Relief -> List Float
lap (Relief relief) =
    Array.toList relief.lap |> List.map .height


{-| The pit lane's heights, one per point of its line.
-}
pitLane : Relief -> List Float
pitLane (Relief relief) =
    relief.pitLane


{-| The lowest and the highest of either line's heights.
-}
lowest : Relief -> Float
lowest (Relief relief) =
    relief.lowest


highest : Relief -> Float
highest (Relief relief) =
    relief.highest


{-| How high the lap stands `metres` round it. A distance past the end of the lap, or
short of its start, is taken round the lap again.

    hill : Relief
    hill =
        fromHeights
            { lap =
                [ { metres = 0, height = 150 }
                , { metres = 100, height = 160 }
                , { metres = 200, height = 150 }
                ]
            , pitLane = []
            }

    at 50 hill
    --> 155

    at 250 hill
    --> 155

-}
at : Float -> Relief -> Float
at metres (Relief relief) =
    let
        length =
            Array.get (Array.length relief.lap - 1) relief.lap
                |> Maybe.map .metres
                |> Maybe.withDefault 0

        wrapped =
            if length > 0 then
                metres - toFloat (floor (metres / length)) * length

            else
                0

        i =
            lastAtOrBefore wrapped relief.lap 0 (Array.length relief.lap - 1)
    in
    case ( Array.get i relief.lap, Array.get (i + 1) relief.lap ) of
        ( Just a, Just b ) ->
            if b.metres > a.metres then
                a.height + (wrapped - a.metres) / (b.metres - a.metres) * (b.height - a.height)

            else
                a.height

        ( Just a, Nothing ) ->
            a.height

        ( Nothing, _ ) ->
            0


lastAtOrBefore : Float -> Array { metres : Float, height : Float } -> Int -> Int -> Int
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
                if mark.metres <= metres then
                    lastAtOrBefore metres array mid hi

                else
                    lastAtOrBefore metres array lo mid

            Nothing ->
                lo
