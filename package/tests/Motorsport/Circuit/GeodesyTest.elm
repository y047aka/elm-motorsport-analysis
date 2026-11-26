module Motorsport.Circuit.GeodesyTest exposing (tests)

import Angle exposing (Angle)
import Expect
import Motorsport.Circuit.Geodesy exposing (Coordinate, Frame, frame, project)
import Quantity
import Test exposing (Test, describe, test)


{-| The frame of Le Mans's kept geometry, and the corner of the survey it
stands at.
-}
leMans : Frame
leMans =
    frame { origin = northWest, parallel = Angle.degrees 47.943644259125485 }


northWest : Coordinate
northWest =
    { lat = Angle.degrees 47.9618722, lon = Angle.degrees 0.2074582 }


{-| Where the survey of a circuit drawn at the equator would stand.
-}
equator : Coordinate
equator =
    { lat = Angle.degrees 0, lon = Angle.degrees 0 }


{-| The place `north` degrees north -- south, if negative -- and `east` degrees
east of another.
-}
from : Float -> Float -> Coordinate -> Coordinate
from north east place =
    { lat = Quantity.plus place.lat (Angle.degrees north)
    , lon = Quantity.plus place.lon (Angle.degrees east)
    }


tests : Test
tests =
    describe "Motorsport.Circuit.Geodesy"
        [ test "the origin is the drawing's zero" <|
            \_ ->
                project leMans northWest
                    |> Expect.equal { x = 0, y = 0 }
        , test "south is down the drawing and east is along it" <|
            \_ ->
                project leMans (from -0.001 0.001 northWest)
                    |> Expect.all
                        [ .x >> Expect.greaterThan 0
                        , .y >> Expect.greaterThan 0
                        ]
        , test "a degree of latitude comes to 111,195 m" <|
            \_ ->
                project leMans (from -1 0 northWest)
                    |> .y
                    |> Expect.within (Expect.Absolute 0.01) 111195.08
        , test "a degree east is a degree north times the cosine of the parallel" <|
            \_ ->
                project leMans (from -1 1 northWest)
                    |> (\one -> one.x / one.y)
                    |> Expect.within (Expect.Absolute 0.000001) (Angle.cos (Angle.degrees 47.943644259125485))
        , test "at 60 degrees north a degree east is half a degree north" <|
            \_ ->
                project (frame { origin = equator, parallel = Angle.degrees 60 }) (from 0 1 equator)
                    |> .x
                    |> Expect.within (Expect.Absolute 0.01) 55597.54
        , test "on its own parallel a degree is a degree whichever way it goes" <|
            \_ ->
                project (frame { origin = equator, parallel = Angle.degrees 0 }) (from -1 1 equator)
                    |> Expect.all
                        [ \one -> Expect.within (Expect.Absolute 0.0001) one.y one.x
                        , .y >> Expect.within (Expect.Absolute 0.01) 111195.08
                        ]
        , test "the frame measures the ground without bending it" <|
            \_ ->
                let
                    south =
                        project leMans (from (-200 / 111195.08) 0 northWest)

                    east =
                        project leMans (from 0 (200 / 74485.27) northWest)
                in
                ( round south.y, round east.x )
                    |> Expect.equal ( 200, 200 )
        ]
