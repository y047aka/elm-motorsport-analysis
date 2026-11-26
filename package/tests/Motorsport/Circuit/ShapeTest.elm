module Motorsport.Circuit.ShapeTest exposing (tests)

import Expect
import Length
import Motorsport.Circuit.Shape as Shape exposing (Shape)
import Test exposing (Test, describe, test)


square : Shape
square =
    Shape.fromMarks
        [ { x = 0, y = 0, metres = Length.meters 0 }
        , { x = 10, y = 0, metres = Length.meters 10 }
        , { x = 10, y = 10, metres = Length.meters 20 }
        , { x = 0, y = 10, metres = Length.meters 30 }
        , { x = 0, y = 0, metres = Length.meters 40 }
        ]


tests : Test
tests =
    describe "Motorsport.Circuit.Shape"
        [ describe "at"
            [ test "a distance past the end of the lap takes it round again" <|
                \_ ->
                    Shape.at (Length.meters 45) square
                        |> Expect.equal { x = 5, y = 0, heading = { x = 1, y = 0 } }
            , test "a lap's own length round is back at the start" <|
                \_ ->
                    Shape.at (Shape.length square) square
                        |> Expect.equal (Shape.at (Length.meters 0) square)
            ]
        ]
