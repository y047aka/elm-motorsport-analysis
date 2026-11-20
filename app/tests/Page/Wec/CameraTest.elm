module Page.Wec.CameraTest exposing (suite)

import Drag.Handle exposing (Place)
import Expect
import Motorsport.Chart.Tracker3d as Tracker3d
import Page.Wec.Camera as Camera exposing (Msg(..))
import Test exposing (Test, describe, test)


{-| A pointer read at `x`, `y`.
-}
press : Int -> Float -> Float -> Place
press id x y =
    { id = id, x = x, y = y }


{-| The camera with one pointer down at the origin.
-}
held : Camera.Model
held =
    Camera.update (Grab (press 1 0 0)) Camera.init


{-| The one camera after a move of its pointer to `x`, `y`.
-}
moved : Float -> Float -> Camera.Model -> Camera.Model
moved x y =
    Camera.update (Move (press 1 x y))


suite : Test
suite =
    describe "Page.Wec.Camera"
        [ test "no turn reaches a map with no pointer held on it" <|
            \_ ->
                (Camera.update (Move (press 1 400 30)) Camera.init).eye.azimuth
                    |> Expect.within (Expect.Absolute 0.0001) Tracker3d.init.azimuth
        , test "a held pointer turns the map by how far it travelled" <|
            \_ ->
                (moved 100 0 held).eye.azimuth
                    |> Expect.within (Expect.Absolute 0.0001)
                        (Tracker3d.init.azimuth - 100 * Tracker3d.perPixel)
        , test "a second finger does not turn the map the first is turning" <|
            \_ ->
                (Camera.update (Move (press 2 300 300)) held).eye.azimuth
                    |> Expect.within (Expect.Absolute 0.0001) held.eye.azimuth
        , test "a second finger is no pick while one is held" <|
            \_ ->
                let
                    taken =
                        Camera.update (Grab (press 2 500 500)) held
                in
                (Camera.update (Move (press 2 900 500)) taken).eye.azimuth
                    |> Expect.within (Expect.Absolute 0.0001) held.eye.azimuth
        , test "the finger that is not turning lets go of nothing" <|
            \_ ->
                Camera.update (Release (press 2 0 0)) held
                    |> Camera.held
                    |> Expect.equal True
        , test "letting go keeps the angle the drag reached" <|
            \_ ->
                let
                    released =
                        moved 100 0 held
                            |> Camera.update (Release (press 1 100 0))
                in
                Expect.all
                    [ Camera.held >> Expect.equal False
                    , \m ->
                        Expect.within (Expect.Absolute 0.0001)
                            m.eye.azimuth
                            (moved 100 0 held).eye.azimuth
                    ]
                    released
        ]
