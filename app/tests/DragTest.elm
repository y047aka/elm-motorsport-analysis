module DragTest exposing (suite)

import Drag exposing (Msg(..), Outcome(..))
import Drag.Handle exposing (Place)
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Drag"
        [ describe "grabbing"
            [ test "a grab from idle carries the caller's own thing" <|
                \_ ->
                    Drag.update (Grab "3" (place 1 100 0)) Drag.init
                        |> Tuple.second
                        |> Expect.equal (Began { location = "3", pointerId = 1, from = place 1 100 0, at = place 1 100 0 })
            , test "a second pointer's grab is refused while one is carried" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Grab "3" (place 1 100 0))
                        |> Tuple.first
                        |> Drag.update (Grab "2" (place 2 300 0))
                        |> Tuple.second
                        |> Expect.equal Kept
            ]
        , describe "moving"
            [ test "the carried pointer's moves are followed" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Grab () (place 1 100 0))
                        |> Tuple.first
                        |> Drag.update (Move (place 1 140 0))
                        |> Tuple.first
                        |> Drag.carrying
                        |> Maybe.map Drag.travel
                        |> Expect.equal (Just { x = 40, y = 0 })
            , test "the step handed back is the carry the move happened in, before the reading" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Grab () (place 1 100 0))
                        |> Tuple.first
                        |> Drag.update (Move (place 1 140 0))
                        |> Tuple.first
                        |> Drag.update (Move (place 1 150 0))
                        |> Tuple.second
                        |> Expect.equal (Stepped { location = (), pointerId = 1, from = place 1 100 0, at = place 1 140 0 })
            , test "another pointer's moves are not the carry's business" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Grab () (place 1 100 0))
                        |> Tuple.first
                        |> Drag.update (Move (place 2 500 0))
                        |> Tuple.second
                        |> Expect.equal Kept
            , test "a move of nothing carried reports nothing" <|
                \_ ->
                    Drag.update (Move (place 1 140 0)) Drag.init
                        |> Expect.equal ( Drag.init, Kept )
            ]
        , describe "letting go"
            [ test "the carrying pointer's release ends the carry at its own place" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Grab () (place 1 100 20))
                        |> Tuple.first
                        |> Drag.update (Move (place 1 140 20))
                        |> Tuple.first
                        |> Drag.update (Drop (place 1 250 20))
                        |> Tuple.second
                        |> Expect.equal (Ended { location = (), travel = { x = 150, y = 0 } })
            , test "another pointer's release leaves the carry alone" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Grab () (place 1 100 0))
                        |> Tuple.first
                        |> Drag.update (Drop (place 2 250 0))
                        |> Tuple.first
                        |> Drag.isCarrying
                        |> Expect.equal True
            , test "a release of nothing carried reports nothing" <|
                \_ ->
                    Drag.update (Drop (place 7 100 0)) Drag.init
                        |> Expect.equal ( Drag.init, Kept )
            ]
        , describe "cancelling"
            [ test "the carrying pointer's cancel ends the carry at the last move" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Grab () (place 1 100 0))
                        |> Tuple.first
                        |> Drag.update (Move (place 1 140 0))
                        |> Tuple.first
                        |> Drag.update (Cancel 1)
                        |> Tuple.second
                        |> Expect.equal (Ended { location = (), travel = { x = 40, y = 0 } })
            , test "the cancel that follows a release reports nothing" <|
                \_ ->
                    Drag.init
                        |> Drag.update (Grab () (place 1 100 0))
                        |> Tuple.first
                        |> Drag.update (Drop (place 1 140 0))
                        |> Tuple.first
                        |> Drag.update (Cancel 1)
                        |> Expect.equal ( Drag.init, Kept )
            , test "a cancel of another pointer's carry does nothing" <|
                \_ ->
                    let
                        grabbed =
                            Drag.update (Grab () (place 1 100 0)) Drag.init
                                |> Tuple.first
                    in
                    Drag.update (Cancel 2) grabbed
                        |> Expect.equal ( grabbed, Kept )
            ]
        ]


place : Int -> Float -> Float -> Place
place id x y =
    { id = id, x = x, y = y }
