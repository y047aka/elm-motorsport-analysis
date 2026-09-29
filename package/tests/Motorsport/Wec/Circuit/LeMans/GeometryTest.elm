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


{-| One surveyed place, three ways it is read: the degrees OpenStreetMap gives
it, the frame's metres before `Layout` rounds them, and the drawing's metres
after. A rounded place stands half a tenth clear of every boundary whatever the
survey said, so the clearance a rounding turns on is worth measuring only on the
reading before it.
-}
type alias Place =
    { degrees : Coordinate
    , raw : Point
    , drawn : Point
    }


places : List Place
places =
    List.append
        (paired (List.map onEarth Geometry.centreline) (Shape.marks lap))
        (paired Geometry.pitLane (layout 2025).pitLane)


onEarth : Geometry.LapPoint -> Coordinate
onEarth point =
    { lat = point.lat, lon = point.lon }


paired : List Coordinate -> List { r | x : Float, y : Float } -> List Place
paired surveyed drawnOver =
    List.map2
        (\degrees drawing ->
            { degrees = degrees
            , raw = project Geometry.frame degrees
            , drawn = { x = drawing.x, y = drawing.y }
            }
        )
        surveyed
        drawnOver


tests : Test
tests =
    describe "Motorsport.Wec.Circuit.LeMans.Geometry"
        [ describe "the frame the points are drawn in"
            [ test "every surveyed place has a drawn one, and no more have one" <|
                \_ ->
                    [ Tuple.pair (List.length Geometry.centreline) (List.length (Shape.marks lap))
                    , Tuple.pair (List.length Geometry.pitLane) (List.length (layout 2025).pitLane)
                    ]
                        |> List.filter (\( surveyed, drawnOver ) -> surveyed /= drawnOver)
                        |> Expect.equal []
            , test "the drawing is the survey, kept to a tenth of a metre" <|
                \_ ->
                    mistakes (\place -> tenthOf place.raw == place.drawn)
                        |> Expect.equal []
            , test "no surveyed place stands where another rounding could put it" <|
                \_ ->
                    places
                        |> List.concatMap (\place -> [ fromAHalfTenth place.raw.x, fromAHalfTenth place.raw.y ])
                        |> List.minimum
                        |> Maybe.withDefault 0
                        |> Expect.atLeast tenthTolerance
            , test "no surveyed place falls below the frame's zero" <|
                \_ ->
                    mistakes (\place -> place.raw.x >= 0 && place.raw.y >= 0)
                        |> Expect.equal []
            , test "the survey stands at Le Mans, and not at swapped degrees" <|
                \_ ->
                    mistakes (\place -> place.degrees.lat >= 47.9 && place.degrees.lat <= 48 && place.degrees.lon >= 0.1 && place.degrees.lon <= 0.3)
                        |> Expect.equal []
            ]
        ]


{-| The positions in the survey of the places where a reading of every place
fails.
-}
mistakes : (Place -> Bool) -> List Int
mistakes holds =
    places
        |> List.indexedMap (\i place -> if holds place then Nothing else Just i)
        |> List.filterMap identity


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
