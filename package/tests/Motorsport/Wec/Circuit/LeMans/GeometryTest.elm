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


{-| The lap and the pit lane as the drawing holds them, which is what the degrees
they were surveyed at are measured against.
-}
drawn : List Point
drawn =
    List.append
        (Shape.marks lap
            |> List.map (\mark -> { x = mark.x, y = mark.y })
        )
        (layout 2025).pitLane


tests : Test
tests =
    describe "Motorsport.Wec.Circuit.LeMans.Geometry"
        [ describe "the frame the points are drawn in"
            [ test "the drawing is the survey, kept to a tenth of a metre" <|
                \_ ->
                    drawn
                        |> List.filter (\place -> not (onATenth place.x && onATenth place.y))
                        |> Expect.equal []
            , test "no drawn tenth stands where another rounding could put it elsewhere" <|
                \_ ->
                    drawn
                        |> List.concatMap (\place -> [ fromAHalfTenth place.x, fromAHalfTenth place.y ])
                        |> List.minimum
                        |> Maybe.withDefault 0
                        |> Expect.atLeast tenthTolerance
            , test "the drawing stands on its own zero, and never below it" <|
                \_ ->
                    drawn
                        |> Expect.all
                            [ List.concatMap (\place -> [ place.x, place.y ])
                                >> List.minimum
                                >> Maybe.withDefault 1
                                >> Expect.equal 0
                            , List.filter (\place -> place.x < 0 || place.y < 0) >> Expect.equal []
                            ]
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


{-| Whether a value stands where the drawing stands: on a tenth of a metre, and not
on some digit further down the projection.
-}
onATenth : Float -> Bool
onATenth value =
    let
        tenths =
            value * 10
    in
    abs (tenths - toFloat (round tenths)) < 1.0e-9


{-| How far a value is from the half-tenth a rounding turns on, in metres.
-}
fromAHalfTenth : Float -> Float
fromAHalfTenth value =
    let
        tenths =
            value * 10 - 0.5
    in
    abs (tenths - toFloat (round tenths)) / 10


{-| How far clear of a half-tenth a drawn value has to stand for the drawing not to
depend on how the arithmetic came out. The last digit a value this size holds is a
fraction of a nanometre, and a projection is a handful of those digits wide, so a
micrometre of room is five orders more than a rounding needs. The tightest place of
this survey stands at 113 micrometres.
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
