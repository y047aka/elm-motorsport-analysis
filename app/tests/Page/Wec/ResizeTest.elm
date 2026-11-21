module Page.Wec.ResizeTest exposing (suite)

import Drag
import Drag.Handle as Handle exposing (Place)
import Expect
import Page.Wec.Resize as Resize exposing (Msg(..))
import Test exposing (Test, describe, test)


fence : Resize.Fence
fence =
    { min = 200, max = Just 600 }


{-| The fence's top, said as the number a size stops at.
-}
top : Float
top =
    Maybe.withDefault 0 fence.max


edge : Resize.Edge
edge =
    { axis = Handle.Across
    , grows = Resize.WithPointer
    , fence = fence
    , id = "test-resize-grip"
    , label = "Resize the test thing"
    , glyph = ""
    , cursor = "cursor-col-resize"
    , marks = True
    }


suite : Test
suite =
    describe "Page.Wec.Resize"
        [ describe "the size following the pointer"
            [ test "a second pointer's grab is refused while one is carried" <|
                \_ ->
                    let
                        refused =
                            startAt 300 |> step (Grab (place 2 100))
                    in
                    Expect.all
                        [ \m -> Expect.equal (startAt 300) m
                        , \m ->
                            step (Move (place 1 340)) m
                                |> .size
                                |> Expect.equal 340
                        ]
                        refused
            , test "a carry moves the size from where it was picked up" <|
                \_ ->
                    startAt 300
                        |> step (Move (place 1 340))
                        |> .size
                        |> Expect.equal 340
            , test "the grip that took the size up is the one said to hold it" <|
                \_ ->
                    Expect.all
                        [ \m -> Resize.held edge.id m |> Expect.equal True
                        , \m -> m |> step (Drop (place 1 300)) |> Resize.held edge.id |> Expect.equal False
                        ]
                        (startAt 300)
            , test "a second grip cannot take the size up" <|
                \_ ->
                    startAt 300
                        |> step (Grab (place 1 300))
                        |> step (Grab (place 2 300))
                        |> Resize.held edge.id
                        |> Expect.equal True
            , test "an arrow key does not move the size under a carried grip" <|
                \_ ->
                    startAt 300
                        |> step (Grab (place 1 300))
                        |> step (Step { x = 1, y = 0 })
                        |> .size
                        |> Expect.equal 300
            , test "the size stops at the fence on either side" <|
                \_ ->
                    Expect.all
                        [ \m ->
                            m
                                |> step (Move (place 1 900))
                                |> .size
                                |> Expect.equal top
                        , \m ->
                            m
                                |> step (Move (place 1 -100))
                                |> .size
                                |> Expect.equal fence.min
                        ]
                        (startAt 300)
            , test "a size with no top of its own goes as far as the pointer takes it" <|
                \_ ->
                    Resize.update { edge | fence = { min = fence.min, max = Nothing } } (Move (place 1 9000)) (startAt 300)
                        |> .size
                        |> Expect.equal 9000
            , test "another pointer's moves are not the carry's business" <|
                \_ ->
                    startAt 300
                        |> step (Move (place 2 500))
                        |> .size
                        |> Expect.equal 300
            ]
        , describe "ending a carry"
            [ test "a release leaves the size where the carry left it" <|
                \_ ->
                    let
                        after =
                            startAt 300
                                |> step (Move (place 1 340))
                                |> step (Drop (place 1 340))
                    in
                    Expect.all
                        [ \m -> Expect.equal 340 m.size
                        , \m -> Expect.equal False (Drag.isCarrying m.carried)
                        ]
                        after
            , test "a cancel leaves the size where the last move left it" <|
                \_ ->
                    startAt 300
                        |> step (Move (place 1 340))
                        |> step (Cancel 1)
                        |> .size
                        |> Expect.equal 340
            , test "the cancel that follows a release changes nothing" <|
                \_ ->
                    let
                        released =
                            startAt 300 |> step (Drop (place 1 400))
                    in
                    step (Cancel 1) released
                        |> Expect.equal released
            ]
        , describe "the arrow keys stepping it"
            [ test "one press takes one step, and Shift takes five" <|
                \_ ->
                    Resize.init 300
                        |> step (Step { x = 1, y = 0 })
                        |> step (Step { x = 5, y = 0 })
                        |> .size
                        |> Expect.equal 360
            , test "the fence the pointer is held by holds the keys too" <|
                \_ ->
                    Resize.init 300
                        |> step (Step { x = 100, y = 0 })
                        |> .size
                        |> Expect.equal top
            ]
        ]



-- HELPERS


startAt : Float -> Resize.Model
startAt size =
    Resize.init size |> step (Grab (place 1 size))


step : Msg -> Resize.Model -> Resize.Model
step msg model =
    Resize.update edge msg model


place : Int -> Float -> Place
place id x =
    { id = id, x = x, y = 0 }
