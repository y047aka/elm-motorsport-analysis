module Page.Wec.ShiftTest exposing (suite)

import Drag
import Drag.Handle exposing (Place)
import Expect
import Page.Wec.Shift as Shift
import Test exposing (Test, describe, test)


{-| The box is carried by `Drag`; these are the carrying the box asks on top of it. That the
travel is added to where the box stands, that the window holds it without pinning it, and
that the pointers that are not carrying it get nothing.
-}
suite : Test
suite =
    describe "Page.Wec.Shift"
        [ test "a pointer that is not the one carrying moves nothing" <|
            \_ ->
                Shift.init "box"
                    |> go (Shift.Grab (place 1 0 0))
                    |> go (Shift.Move (place 2 500 500))
                    |> (\m -> ( m.x, m.y ))
                    |> Expect.equal ( 0, 0 )
        , test "a throw past the window comes back the way it came, free" <|
            \_ ->
                Shift.init "box"
                    |> go (Shift.Grab (place 1 0 0))
                    |> go (Shift.Move (place 1 -5000 0))
                    |> .x
                    |> Expect.equal -4000
        , test "and back the way it came is free: the clamp stops the box, not the carry" <|
            \_ ->
                Shift.init "box"
                    |> go (Shift.Grab (place 1 0 0))
                    |> go (Shift.Move (place 1 -5000 0))
                    |> go (Shift.Move (place 1 400 0))
                    |> .x
                    |> Expect.equal 400
        , test "the box's own place at the pick is what the travel is added to" <|
            \_ ->
                Shift.init "box"
                    |> go (Shift.Step { x = 1, y = 0 })
                    |> go (Shift.Grab (place 1 100 100))
                    |> go (Shift.Move (place 1 150 100))
                    |> .x
                    |> Expect.equal 70
        , test "another pointer's release leaves the box carried" <|
            \_ ->
                Shift.init "box"
                    |> go (Shift.Grab (place 1 0 0))
                    |> go (Shift.Drop (place 2 10 10))
                    |> go (Shift.Move (place 1 50 0))
                    |> .x
                    |> Expect.equal 50
        ]


go : Shift.Msg -> Shift.Model -> Shift.Model
go sub m =
    Shift.update sub m |> Tuple.first


place : Int -> Float -> Float -> Place
place id x y =
    { id = id, x = x, y = y }
