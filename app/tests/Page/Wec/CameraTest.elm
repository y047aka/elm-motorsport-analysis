module Page.Wec.CameraTest exposing (suite)

import Angle
import Drag
import Drag.Handle exposing (Device(..), Place)
import Expect
import Motorsport.Chart.Tracker3d as Tracker3d
import Page.Wec.Camera as Camera exposing (Msg(..))
import Quantity
import Test exposing (Test, describe, test)


{-| A pointer read at `x`, `y`.
-}
press : Int -> Float -> Float -> Place
press id x y =
    { id = id, x = x, y = y }


{-| The camera with one finger down at the origin.
-}
held : Camera.Model
held =
    Camera.update (Grab Touch (press 1 0 0)) Camera.init


{-| The one camera after a move of its pointer to `x`, `y`.
-}
moved : Float -> Float -> Camera.Model -> Camera.Model
moved x y =
    Camera.update (Move (press 1 x y))


{-| Which way round the map is looked at, in radians.
-}
spin : Camera.Model -> Float
spin =
    .eye >> .azimuth >> Angle.inRadians


{-| The azimuth the map opened at, rolled by `pixels` of the pointer's travel.
-}
rolled : Float -> Float
rolled pixels =
    Quantity.plus Tracker3d.init.azimuth (Tracker3d.roll pixels)
        |> Angle.inRadians


suite : Test
suite =
    describe "Page.Wec.Camera"
        [ test "no turn reaches a map with no pointer held on it" <|
            \_ ->
                (Camera.update (Move (press 1 400 30)) Camera.init).eye.azimuth
                    |> Angle.inRadians
                    |> Expect.within (Expect.Absolute 0.0001) (spin Camera.init)
        , test "a held pointer turns the map by how far it travelled" <|
            \_ ->
                moved 100 0 held
                    |> spin
                    |> Expect.within (Expect.Absolute 0.0001) (rolled 100)
        , test "a mouse turns the map the other way from a finger" <|
            \_ ->
                let
                    gripped =
                        Camera.update (Grab Mouse (press 1 0 0)) Camera.init
                in
                Camera.update (Move (press 1 100 0)) gripped
                    |> spin
                    |> Expect.within (Expect.Absolute 0.0001) (rolled -100)
        , test "a scroll keeps its own way, whatever turned the map last" <|
            \_ ->
                Camera.update (Wheel { x = 100, y = 0 }) Camera.init
                    |> spin
                    |> Expect.within (Expect.Absolute 0.0001) (rolled (100 * (1 / 3)))
        , test "a second finger does not turn the map the first is turning" <|
            \_ ->
                (Camera.update (Move (press 2 300 300)) held).eye.azimuth
                    |> Angle.inRadians
                    |> Expect.within (Expect.Absolute 0.0001) (spin held)
        , test "a second finger is no pick while one is held" <|
            \_ ->
                let
                    taken =
                        Camera.update (Grab Touch (press 2 500 500)) held
                in
                (Camera.update (Move (press 2 900 500)) taken).eye.azimuth
                    |> Angle.inRadians
                    |> Expect.within (Expect.Absolute 0.0001) (spin held)
        , test "the finger that is not turning lets go of nothing" <|
            \_ ->
                Camera.update (Drop (press 2 0 0)) held
                    |> .carried
                    |> Drag.isCarrying
                    |> Expect.equal True
        , test "letting go keeps the angle the drag reached" <|
            \_ ->
                let
                    released =
                        moved 100 0 held
                            |> Camera.update (Drop (press 1 100 0))
                in
                Expect.all
                    [ .carried >> Drag.isCarrying >> Expect.equal False
                    , \m ->
                        Expect.within (Expect.Absolute 0.0001)
                            (spin m)
                            (spin (moved 100 0 held))
                    ]
                    released
        ]
