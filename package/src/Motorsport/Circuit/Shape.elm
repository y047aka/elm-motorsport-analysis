module Motorsport.Circuit.Shape exposing
    ( Shape, Mark, Point, fromMarks
    , length, marks
    , Position, at
    , Nearest, nearest
    )

{-| A circuit's lap as a line on the ground, each point of it marked with how
far round the lap it is.

@docs Shape, Mark, Point, fromMarks
@docs length, marks
@docs Position, at
@docs Nearest, nearest

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
    in
    { x = a.x + fraction * (b.x - a.x)
    , y = a.y + fraction * (b.y - a.y)
    , heading = heading a b
    }


heading : Mark -> Mark -> Point
heading a b =
    let
        dx =
            b.x - a.x

        dy =
            b.y - a.y

        norm =
            sqrt (dx * dx + dy * dy)
    in
    if norm > 0 then
        { x = dx / norm, y = dy / norm }

    else
        { x = 0, y = 0 }


{-| Where on the line a place falls: how far round the lap the nearest point of
it stands, where on the drawing that is, and how far from the line the place was.

A lap surveyed from its centreline is a line nowhere the path a car took, so
`distance` is how far the line stands from the place and not how far a car was
from where it should have been: even a place on the line sits metres from the apex
a car went through. What an answer is measured to is how far apart the two marks
either side of `metres` are.

The line passes some places twice over: the finish line, and the start straight
the pit lane runs beside. The reading is whichever end of the lap the nearest
point of the line stands at, and which lap a car was on is not the line's to say.

-}
type alias Nearest =
    { metres : Float
    , position : Position
    , distance : Float
    }


{-| The nearest point of the line to a place in the line's own metres.

    square : Shape
    square =
        fromMarks
            [ { x = 0, y = 0, metres = 0 }
            , { x = 10, y = 0, metres = 10 }
            , { x = 10, y = 10, metres = 20 }
            , { x = 0, y = 10, metres = 30 }
            , { x = 0, y = 0, metres = 40 }
            ]

`{ x = 4, y = 13 }` is 3 m short of the far side of the square, 26 m round it
from the start:

    nearest { x = 4, y = 13 } square

    --> { metres = 26, position = { x = 4, y = 10, heading = { x = -1, y = 0 } }, distance = 3 }

A place a long way off the line is answered the same way, so a sample from a road
the circuit is not comes back as a big `distance` rather than as nowhere:

    nearest { x = 40, y = 5 } square

    --> { metres = 15, position = { x = 10, y = 5, heading = { x = 0, y = 1 } }, distance = 30 }

-}
nearest : Point -> Shape -> Nearest
nearest point (Shape shape) =
    case List.map (onStretch point) (stretches (Array.toList shape.marks)) of
        first :: rest ->
            List.foldl closer first rest

        [] ->
            { metres = 0, position = { x = 0, y = 0, heading = { x = 0, y = 0 } }, distance = 0 }


{-| The line's stretches, in the order it is driven. The last mark is the first
again, so a closed lap includes the stretch that crosses the finish line.
-}
stretches : List Mark -> List ( Mark, Mark )
stretches points =
    List.map2 Tuple.pair points (List.drop 1 points)


closer : Nearest -> Nearest -> Nearest
closer candidate best =
    if candidate.distance < best.distance then
        candidate

    else
        best


onStretch : Point -> ( Mark, Mark ) -> Nearest
onStretch point ( a, b ) =
    let
        dx =
            b.x - a.x

        dy =
            b.y - a.y

        squared =
            dx * dx + dy * dy

        along =
            if squared > 0 then
                clamp 0 1 (((point.x - a.x) * dx + (point.y - a.y) * dy) / squared)

            else
                0

        x =
            a.x + along * dx

        y =
            a.y + along * dy
    in
    { metres = a.metres + along * (b.metres - a.metres)
    , position = { x = x, y = y, heading = heading a b }
    , distance = sqrt ((point.x - x) ^ 2 + (point.y - y) ^ 2)
    }
