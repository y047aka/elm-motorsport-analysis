module Motorsport.Circuit.Shape exposing
    ( Shape, Mark, Point, fromMarks
    , length, marks
    , Position, at
    )

{-| A circuit's lap as a line on the ground, each point of it marked with how
far round the lap it is.

@docs Shape, Mark, Point, fromMarks
@docs length, marks
@docs Position, at

-}

import Array exposing (Array)


type Shape
    = Shape
        { marks : Array Mark
        , length : Float
        }


{-| A point of the line, `metres` round the lap from the finish line.
-}
type alias Mark =
    { x : Float
    , y : Float
    , metres : Float
    }


type alias Point =
    { x : Float
    , y : Float
    }


{-| The marks in the order the lap is driven, from the finish line and back to
it: the last is the first again, marked with the whole lap's length.
-}
fromMarks : List Mark -> Shape
fromMarks list =
    let
        array =
            Array.fromList list
    in
    Shape
        { marks = array
        , length =
            Array.get (Array.length array - 1) array
                |> Maybe.map .metres
                |> Maybe.withDefault 0
        }


length : Shape -> Float
length (Shape shape) =
    shape.length


marks : Shape -> List Mark
marks (Shape shape) =
    Array.toList shape.marks


{-| A place on the line, and which way the lap runs there as a vector one metre
long.
-}
type alias Position =
    { x : Float
    , y : Float
    , heading : Point
    }


{-| Where on the line a distance round the lap falls. A distance past the end
of the lap, or short of its start, is taken round the lap again.

    square : Shape
    square =
        fromMarks
            [ { x = 0, y = 0, metres = 0 }
            , { x = 10, y = 0, metres = 10 }
            , { x = 10, y = 10, metres = 20 }
            , { x = 0, y = 10, metres = 30 }
            , { x = 0, y = 0, metres = 40 }
            ]

    at 15 square
    --> { x = 10, y = 5, heading = { x = 0, y = 1 } }

    at 45 square
    --> { x = 5, y = 0, heading = { x = 1, y = 0 } }

-}
at : Float -> Shape -> Position
at metres (Shape shape) =
    let
        wrapped =
            if shape.length > 0 then
                metres - toFloat (floor (metres / shape.length)) * shape.length

            else
                0

        i =
            lastAtOrBefore wrapped shape.marks 0 (Array.length shape.marks - 1)
    in
    case ( Array.get i shape.marks, Array.get (i + 1) shape.marks ) of
        ( Just a, Just b ) ->
            between a b wrapped

        ( Just a, Nothing ) ->
            { x = a.x, y = a.y, heading = { x = 0, y = 0 } }

        ( Nothing, _ ) ->
            { x = 0, y = 0, heading = { x = 0, y = 0 } }


{-| The index of the last mark at or before `metres`, between `lo`, which is,
and `hi`, which is not unless it is the only one left.
-}
lastAtOrBefore : Float -> Array Mark -> Int -> Int -> Int
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


between : Mark -> Mark -> Float -> Position
between a b metres =
    let
        span =
            b.metres - a.metres

        fraction =
            if span > 0 then
                (metres - a.metres) / span

            else
                0

        dx =
            b.x - a.x

        dy =
            b.y - a.y

        norm =
            sqrt (dx * dx + dy * dy)
    in
    { x = a.x + fraction * dx
    , y = a.y + fraction * dy
    , heading =
        if norm > 0 then
            { x = dx / norm, y = dy / norm }

        else
            { x = 0, y = 0 }
    }
