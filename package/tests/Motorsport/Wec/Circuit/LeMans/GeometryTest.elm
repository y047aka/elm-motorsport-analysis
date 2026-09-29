module Motorsport.Wec.Circuit.LeMans.GeometryTest exposing (tests)

import Expect
import Motorsport.Circuit.Geodesy exposing (Coordinate, project)
import Motorsport.Circuit.Shape as Shape exposing (Nearest, Point, Shape)
import Motorsport.Wec.Circuit.LeMans.Geometry as Geometry
import Motorsport.Wec.Circuit.LeMans.Layout exposing (layout)
import Test exposing (Test, describe, test)


{-| 2025's Le Mans: the round a checkout keeps, and the shape every view draws,
so every reading here is of what is on the screen.
-}
lap : Shape
lap =
    (layout 2025).shape


lapLength : Float
lapLength =
    Shape.length lap


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
    List.map (project Geometry.frame) (List.append (List.map .coordinates samples) pitway)


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
                    samples
                        |> List.map .coordinates
                        |> List.filter (\coordinate -> coordinate.lat < 47.9 || coordinate.lat > 48 || coordinate.lon < 0.1 || coordinate.lon > 0.3)
                        |> Expect.equal []
            ]
        , describe "a GPS log read against the lap"
            [ test "a sample at a surveyed point reads as that point of the lap" <|
                \_ ->
                    samples
                        |> List.map (\sample -> apart sample.metres (read sample.coordinates))
                        |> List.maximum
                        |> Maybe.withDefault 1.0e9
                        |> Expect.atMost 1
            , test "a receiver some metres off still reads as the same place round the lap" <|
                \_ ->
                    samples
                        |> List.indexedMap (\i sample -> apart sample.metres (read (drift i sample.coordinates)))
                        |> List.maximum
                        |> Maybe.withDefault 1.0e9
                        |> Expect.atMost 15
            , test "a car in the pit lane is placed on the lap it runs beside, and read as off the line" <|
                \_ ->
                    pitway
                        |> List.map reading
                        |> Expect.all
                            [ List.map .distance >> List.maximum >> Maybe.withDefault 1.0e9 >> Expect.atMost 50
                            , List.map .metres >> List.filter farFromTheStartStraight >> Expect.equal []
                            ]
            ]
        ]


{-| A place the lap was surveyed at, and how far round the lap it stands.
-}
type alias Sample =
    { metres : Float
    , coordinates : Coordinate
    }


samples : List Sample
samples =
    List.map
        (\point ->
            { metres = point.metres
            , coordinates = { lat = point.lat, lon = point.lon }
            }
        )
        Geometry.centreline


{-| Where the pit lane was surveyed. It is a line of its own, with no distance
round the lap marked on it.
-}
pitway : List Coordinate
pitway =
    List.map
        (\point ->
            { lat = point.lat, lon = point.lon }
        )
        Geometry.pitLane


read : Coordinate -> Float
read coordinates =
    (reading coordinates).metres


reading : Coordinate -> Nearest
reading coordinates =
    Shape.nearest (project Geometry.frame coordinates) lap


{-| How far round the lap two readings are, the short way: the lap ends where it
starts, so a reading just past the line and one just short of it are neighbours.
-}
apart : Float -> Float -> Float
apart a b =
    let
        difference =
            abs (a - b)
    in
    min difference (lapLength - difference)


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


{-| Readings that are nowhere near the start straight the pit lane runs beside.
-}
farFromTheStartStraight : Float -> Bool
farFromTheStartStraight metres =
    metres >= 700 && metres <= 12900


{-| About ten metres off, the way a GPS receiver is wrong: 0.00009 degrees of
latitude, or 0.00013 of longitude at this latitude. Successive samples drift in
different directions, as a log's do.
-}
drift : Int -> Coordinate -> Coordinate
drift i coordinates =
    let
        error =
            List.drop (modBy (List.length offsets) i) offsets
                |> List.head
                |> Maybe.withDefault { lat = 0, lon = 0 }
    in
    { lat = coordinates.lat + error.lat, lon = coordinates.lon + error.lon }


offsets : List Coordinate
offsets =
    [ { lat = 0.00009, lon = 0 }
    , { lat = 0, lon = -0.00013 }
    , { lat = -0.00006, lon = 0.00008 }
    , { lat = 0.00004, lon = 0.00004 }
    ]
