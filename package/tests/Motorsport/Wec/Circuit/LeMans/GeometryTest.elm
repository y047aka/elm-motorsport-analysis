module Motorsport.Wec.Circuit.LeMans.GeometryTest exposing (tests)

import Expect
import Motorsport.Circuit.Geodesy exposing (Coordinate, project)
import Motorsport.Circuit.Shape as Shape exposing (Point, Shape)
import Motorsport.Wec.Circuit.LeMans.Geometry as Geometry
import Motorsport.Wec.Circuit.LeMans.Layout exposing (layout)
import Test exposing (Test, describe, test)


{-| 2025's Le Mans: the round a checkout keeps, and the shape every view draws.
-}
lap : Shape
lap =
    (layout 2025).shape


{-| The lap and the pit lane as the drawing holds them.
-}
drawn : List Point
drawn =
    List.append
        (Shape.marks lap
            |> List.map (\mark -> { x = mark.x, y = mark.y })
        )
        (layout 2025).pitLane


{-| Where every place the lap and the pit lane were surveyed falls in the
frame's metres, before `Layout` rounds it to a tenth. A drawn point has been
rounded already, and so stands half a tenth clear of every boundary whatever
the survey said; only here does a rounding have a clearance worth measuring.
-}
survey : List Point
survey =
    List.append
        (List.map (onEarth >> project Geometry.frame) Geometry.centreline)
        (List.map (project Geometry.frame) Geometry.pitLane)


tests : Test
tests =
    describe "Motorsport.Wec.Circuit.LeMans.Geometry"
        [ describe "the frame the points are drawn in"
            [ test "the drawing is the survey, kept to a tenth of a metre" <|
                \_ ->
                    List.map tenthOf survey
                        |> Expect.equal drawn
            , test "no surveyed place stands where another rounding could put it" <|
                \_ ->
                    survey
                        |> List.concatMap (\place -> [ fromAHalfTenth place.x, fromAHalfTenth place.y ])
                        |> List.minimum
                        |> Maybe.withDefault 0
                        |> Expect.atLeast tenthTolerance
            , test "no surveyed place falls below the frame's zero" <|
                \_ ->
                    survey
                        |> List.filter (\place -> place.x < 0 || place.y < 0)
                        |> Expect.equal []
            , test "the survey stands at Le Mans, and not at swapped degrees" <|
                \_ ->
                    Geometry.centreline
                        |> List.filter (\point -> point.lat < 47.9 || point.lat > 48 || point.lon < 0.1 || point.lon > 0.3)
                        |> Expect.equal []
            ]
        ]


{-| A place on the earth, without the distance round the lap that rides along
with it in the survey. The pit lane's points need no such cutting: `PitPoint`
and this are the same shape.
-}
onEarth : Geometry.LapPoint -> Coordinate
onEarth point =
    { lat = point.lat, lon = point.lon }


{-| `Layout`'s rounding: the survey's own resolution, a tenth of a metre.
-}
tenthOf : Point -> Point
tenthOf place =
    { x = tenth place.x, y = tenth place.y }


tenth : Float -> Float
tenth value =
    toFloat (round (value * 10)) / 10


{-| How far a value is from the half-tenth a rounding turns on, in metres.
-}
fromAHalfTenth : Float -> Float
fromAHalfTenth value =
    let
        tenths =
            value * 10 - 0.5
    in
    abs (tenths - toFloat (round tenths)) / 10


{-| How far clear of a half-tenth a projected value has to stand for the drawing
not to depend on how the arithmetic came out. The last digit a value this size
holds is a fraction of a nanometre, and a projection is a handful of those digits
wide — two languages' roundings of the same degrees may disagree in the last of
them — so a micrometre of room is five orders more than a rounding needs. The
tightest place of this survey stands 113 micrometres clear.
-}
tenthTolerance : Float
tenthTolerance =
    1.0e-6
