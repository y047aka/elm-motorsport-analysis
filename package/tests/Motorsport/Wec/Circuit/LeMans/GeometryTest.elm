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


tests : Test
tests =
    describe "Motorsport.Wec.Circuit.LeMans.Geometry"
        [ describe "the frame the points are drawn in"
            [ test "the lap is drawn where its own coordinates say it is" <|
                \_ ->
                    centreline
                        |> List.map (\sample -> between sample.drawn (project Geometry.frame sample.coordinates))
                        |> List.maximum
                        |> Maybe.withDefault 1.0e9
                        |> Expect.atMost 0.1
            , test "so is the pit lane" <|
                \_ ->
                    pitLane
                        |> List.map (\place -> between place.drawn (project Geometry.frame place.coordinates))
                        |> List.maximum
                        |> Maybe.withDefault 1.0e9
                        |> Expect.atMost 0.1
            , test "the survey stands at Le Mans, and not at swapped degrees" <|
                \_ ->
                    centreline
                        |> List.map .coordinates
                        |> List.filter (\coordinate -> coordinate.lat < 47.9 || coordinate.lat > 48 || coordinate.lon < 0.1 || coordinate.lon > 0.3)
                        |> Expect.equal []
            ]
        , describe "a GPS log read against the lap"
            [ test "a sample at a surveyed point reads as that point of the lap" <|
                \_ ->
                    centreline
                        |> List.map (\sample -> apart sample.metres (read sample.coordinates))
                        |> List.maximum
                        |> Maybe.withDefault 1.0e9
                        |> Expect.atMost 1
            , test "a receiver some metres off still reads as the same place round the lap" <|
                \_ ->
                    centreline
                        |> List.indexedMap (\i sample -> apart sample.metres (read (drift i sample.coordinates)))
                        |> List.maximum
                        |> Maybe.withDefault 1.0e9
                        |> Expect.atMost 15
            , test "a car in the pit lane is placed on the lap it runs beside, and read as off the line" <|
                \_ ->
                    List.map (reading << .coordinates) pitLane
                        |> Expect.all
                            [ List.map .distance >> List.maximum >> Maybe.withDefault 1.0e9 >> Expect.atMost 50
                            , List.map .metres >> List.filter farFromTheStartStraight >> Expect.equal []
                            ]
            ]
        ]


{-| A surveyed point of the lap, as the earth gives it and as the drawing holds it.
-}
type alias Sample =
    { metres : Float
    , coordinates : Coordinate
    , drawn : Point
    }


centreline : List Sample
centreline =
    List.map
        (\point ->
            { metres = point.metres
            , coordinates = { lat = point.lat, lon = point.lon }
            , drawn = { x = point.x, y = point.y }
            }
        )
        Geometry.centreline


{-| Where the pit lane was surveyed. It is a line of its own, with no distance
round the lap marked on it.
-}
type alias Place =
    { coordinates : Coordinate
    , drawn : Point
    }


pitLane : List Place
pitLane =
    List.map
        (\point ->
            { coordinates = { lat = point.lat, lon = point.lon }
            , drawn = { x = point.x, y = point.y }
            }
        )
        Geometry.pitLane


read : Coordinate -> Float
read coordinates =
    (reading coordinates).metres


reading : Coordinate -> Nearest
reading coordinates =
    Shape.nearest (project Geometry.frame coordinates) lap


{-| How far the drawing is from where the earth says a point is.
-}
between : Point -> Point -> Float
between a b =
    sqrt ((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)


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
