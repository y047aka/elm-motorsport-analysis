module Page.Wec.ResizeTest exposing (suite)

import Drag
import Drag.Handle exposing (Pointer)
import Expect
import Page.Wec.Resize as Resize exposing (Msg(..))
import Test exposing (Test, describe, test)


fence : Resize.Fence
fence =
    { min = 200, max = 600, step = 20 }


suite : Test
suite =
    describe "Page.Wec.Resize"
        [ describe "the width following the pointer"
            [ test "a second pointer's grab is refused while one is carried" <|
                \_ ->
                    let
                        refused =
                            startAt 300 |> step (Grab (pointer 2 100))
                    in
                    Expect.all
                        [ \m -> Expect.equal (startAt 300) m
                        , \m ->
                            step (Carrying (pointer 1 340)) m
                                |> .width
                                |> Expect.equal 340
                        ]
                        refused
            , test "a carry moves the width from where it was picked up" <|
                \_ ->
                    startAt 300
                        |> step (Carrying (pointer 1 340))
                        |> .width
                        |> Expect.equal 340
            , test "the width stops at the fence on either side" <|
                \_ ->
                    Expect.all
                        [ \m ->
                            m
                                |> step (Carrying (pointer 1 900))
                                |> .width
                                |> Expect.equal fence.max
                        , \m ->
                            m
                                |> step (Carrying (pointer 1 -100))
                                |> .width
                                |> Expect.equal fence.min
                        ]
                        (startAt 300)
            , test "another pointer's moves are not the carry's business" <|
                \_ ->
                    startAt 300
                        |> step (Carrying (pointer 2 500))
                        |> .width
                        |> Expect.equal 300
            ]
        , describe "ending a carry"
            [ test "a release leaves the width where the carry left it" <|
                \_ ->
                    let
                        after =
                            startAt 300
                                |> step (Carrying (pointer 1 340))
                                |> step (Release (pointer 1 340))
                    in
                    Expect.all
                        [ \m -> Expect.equal 340 m.width
                        , \m -> Expect.equal False (Drag.isCarrying m.carried)
                        ]
                        after
            , test "a cancel leaves the width where the last move left it" <|
                \_ ->
                    startAt 300
                        |> step (Carrying (pointer 1 340))
                        |> step (Cancel 1)
                        |> .width
                        |> Expect.equal 340
            , test "the cancel that follows a release changes nothing" <|
                \_ ->
                    let
                        released =
                            startAt 300 |> step (Release (pointer 1 400))
                    in
                    step (Cancel 1) released
                        |> Expect.equal released
            ]
        , describe "stepping by hand"
            [ test "the arrow keys take the step, and hold at the fence" <|
                \_ ->
                    Expect.all
                        [ \m ->
                            m |> step (Step 5) |> .width |> Expect.equal 400
                        , \m ->
                            m |> step (Step 100) |> .width |> Expect.equal fence.max
                        ]
                        (Resize.init 300)
            ]
        ]



-- HELPERS


startAt : Float -> Resize.Model
startAt width =
    Resize.init width |> step (Grab (pointer 1 width))


step : Msg -> Resize.Model -> Resize.Model
step msg model =
    Resize.update fence msg model


pointer : Int -> Float -> Pointer
pointer id x =
    { id = id, x = x }
