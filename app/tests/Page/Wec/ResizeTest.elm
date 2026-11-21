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
                            step (Carrying (place 1 340)) m
                                |> .size
                                |> Expect.equal 340
                        ]
                        refused
            , test "a carry moves the size from where it was picked up" <|
                \_ ->
                    startAt 300
                        |> step (Carrying (place 1 340))
                        |> .size
                        |> Expect.equal 340
            , test "the grip that took the size up is the one said to hold it" <|
                \_ ->
                    Expect.all
                        [ \m ->
                            Expect.equal (Just edge.id) m.grip
                        , \m ->
                            m |> step (Release (place 1 300)) |> .grip |> Expect.equal Nothing
                        ]
                        (startAt 300)
            , test "the size stops at the fence on either side" <|
                \_ ->
                    Expect.all
                        [ \m ->
                            m
                                |> step (Carrying (place 1 900))
                                |> .size
                                |> Expect.equal top
                        , \m ->
                            m
                                |> step (Carrying (place 1 -100))
                                |> .size
                                |> Expect.equal fence.min
                        ]
                        (startAt 300)
            , test "a size with no top of its own goes as far as the pointer takes it" <|
                \_ ->
                    Resize.update { edge | fence = { min = fence.min, max = Nothing } } (Carrying (place 1 9000)) (startAt 300)
                        |> .size
                        |> Expect.equal 9000
            , test "another pointer's moves are not the carry's business" <|
                \_ ->
                    startAt 300
                        |> step (Carrying (place 2 500))
                        |> .size
                        |> Expect.equal 300
            ]
        , describe "ending a carry"
            [ test "a release leaves the size where the carry left it" <|
                \_ ->
                    let
                        after =
                            startAt 300
                                |> step (Carrying (place 1 340))
                                |> step (Release (place 1 340))
                    in
                    Expect.all
                        [ \m -> Expect.equal 340 m.size
                        , \m -> Expect.equal False (Drag.isCarrying m.carried)
                        ]
                        after
            , test "a cancel leaves the size where the last move left it" <|
                \_ ->
                    startAt 300
                        |> step (Carrying (place 1 340))
                        |> step (Cancel 1)
                        |> .size
                        |> Expect.equal 340
            , test "the cancel that follows a release changes nothing" <|
                \_ ->
                    let
                        released =
                            startAt 300 |> step (Release (place 1 400))
                    in
                    step (Cancel 1) released
                        |> Expect.equal released
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
