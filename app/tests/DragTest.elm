module DragTest exposing (suite)

import Drag exposing (Msg(..))
import Drag.Handle exposing (Pointer)
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Drag"
        [ describe "picking up"
            [ test "a pick from idle carries the caller's own thing" <|
                \_ ->
                    Drag.update (Pick "3" (pointer 1 100)) Drag.init
                        |> Tuple.first
                        |> Drag.carrying
                        |> Expect.equal (Just { location = "3", pointerId = 1, from = 100, at = 100 })
            , test "a second pointer's pick is refused while one is carried" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Pick "3" (pointer 1 100))
                        |> Tuple.first
                        |> Drag.update (Pick "2" (pointer 2 300))
                        |> Tuple.first
                        |> Drag.carrying
                        |> Maybe.map .location
                        |> Expect.equal (Just "3")
            ]
        , describe "moving"
            [ test "the carried pointer's moves are followed" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Pick () (pointer 1 100))
                        |> Tuple.first
                        |> Drag.update (Move (pointer 1 140))
                        |> Tuple.first
                        |> Drag.carrying
                        |> Maybe.map Drag.travel
                        |> Expect.equal (Just 40)
            , test "another pointer's moves are not the carry's business" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Pick () (pointer 1 100))
                        |> Tuple.first
                        |> Drag.update (Move (pointer 2 500))
                        |> Tuple.first
                        |> Drag.carrying
                        |> Maybe.map Drag.travel
                        |> Expect.equal (Just 0)
            , test "a move of nothing carried reports nothing" <|
                \_ ->
                    Drag.update (Move (pointer 1 140)) Drag.init
                        |> Expect.equal ( Drag.init, Nothing )
            ]
        , describe "letting go"
            [ test "the carrying pointer's release ends the carry at its own place" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Pick () (pointer 1 100))
                        |> Tuple.first
                        |> Drag.update (Move (pointer 1 140))
                        |> Tuple.first
                        |> Drag.update (Drop (pointer 1 250))
                        |> Tuple.second
                        |> Expect.equal (Just { location = (), travel = 150 })
            , test "another pointer's release leaves the carry alone" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Pick () (pointer 1 100))
                        |> Tuple.first
                        |> Drag.update (Drop (pointer 2 250))
                        |> Tuple.first
                        |> Drag.isCarrying
                        |> Expect.equal True
            , test "a release of nothing carried reports nothing" <|
                \_ ->
                    Drag.update (Drop (pointer 7 100)) Drag.init
                        |> Expect.equal ( Drag.init, Nothing )
            ]
        , describe "cancelling"
            [ test "the carrying pointer's cancel ends the carry at the last move" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Pick () (pointer 1 100))
                        |> Tuple.first
                        |> Drag.update (Move (pointer 1 140))
                        |> Tuple.first
                        |> Drag.update (Cancel 1)
                        |> Tuple.second
                        |> Expect.equal (Just { location = (), travel = 40 })
            , test "the cancel that follows a release reports nothing" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Pick () (pointer 1 100))
                        |> Tuple.first
                        |> Drag.update (Drop (pointer 1 140))
                        |> Tuple.first
                        |> Drag.update (Cancel 1)
                        |> Expect.equal ( Drag.init, Nothing )
            , test "a cancel of another pointer's carry does nothing" <|
                \_ ->
                    let
                        grabbed =
                            Drag.update (Pick () (pointer 1 100)) Drag.init
                                |> Tuple.first
                    in
                    Drag.update (Cancel 2) grabbed
                        |> Expect.equal ( grabbed, Nothing )
            ]
        ]


pointer : Int -> Float -> Pointer
pointer id x =
    { id = id, x = x }
