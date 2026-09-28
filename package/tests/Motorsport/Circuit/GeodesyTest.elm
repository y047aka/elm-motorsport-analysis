module Motorsport.Circuit.GeodesyTest exposing (tests)

import Expect
import Motorsport.Circuit.Geodesy exposing (Coordinate, Frame, frame, project)
import Test exposing (Test, describe, test)


{-| The frame `Motorsport.Wec.Circuit.LeMans.Geometry` writes, and the corner of
the survey it stands at.
-}
leMans : Frame
leMans =
    frame { origin = northWest, parallel = 47.943644259125485 }


northWest : Coordinate
northWest =
    { lat = 47.9618722, lon = 0.2074582 }


tests : Test
tests =
    describe "Motorsport.Circuit.Geodesy"
        [ test "the origin is the drawing's zero" <|
            \_ ->
                project leMans northWest
                    |> Expect.equal { x = 0, y = 0 }
        , test "south is down the drawing and east is along it" <|
            \_ ->
                project leMans { lat = northWest.lat - 0.001, lon = northWest.lon + 0.001 }
                    |> Expect.all
                        [ .x >> Expect.greaterThan 0
                        , .y >> Expect.greaterThan 0
                        ]
        , test "a degree of latitude comes to 111,195 m" <|
            \_ ->
                project leMans { lat = northWest.lat - 1, lon = northWest.lon }
                    |> .y
                    |> Expect.within (Expect.Absolute 0.01) 111195.08
        , test "a degree east is a degree north times the cosine of the parallel" <|
            \_ ->
                project leMans { lat = northWest.lat - 1, lon = northWest.lon + 1 }
                    |> (\one -> one.x / one.y)
                    |> Expect.within (Expect.Absolute 0.000001) (cos (degrees 47.943644259125485))
        , test "at 60 degrees north a degree east is half a degree north" <|
            \_ ->
                project (frame { origin = { lat = 0, lon = 0 }, parallel = 60 }) { lat = 0, lon = 1 }
                    |> .x
                    |> Expect.within (Expect.Absolute 0.01) 55597.54
        , test "on its own parallel a degree is a degree whichever way it goes" <|
            \_ ->
                project (frame { origin = { lat = 0, lon = 0 }, parallel = 0 }) { lat = -1, lon = 1 }
                    |> Expect.all
                        [ \one -> Expect.within (Expect.Absolute 0.0001) one.y one.x
                        , .y >> Expect.within (Expect.Absolute 0.01) 111195.08
                        ]
        , test "the frame measures the ground without bending it" <|
            \_ ->
                let
                    south =
                        project leMans { lat = northWest.lat - 200 / 111195.08, lon = northWest.lon }

                    east =
                        project leMans { lat = northWest.lat, lon = northWest.lon + 200 / 74485.27 }
                in
                ( round south.y, round east.x )
                    |> Expect.equal ( 200, 200 )
        ]
