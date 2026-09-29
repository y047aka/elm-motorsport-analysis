module Motorsport.Circuit.ShapeTest exposing (tests)

import Expect
import Motorsport.Circuit.Shape as Shape exposing (Shape)
import Test exposing (Test, describe, test)


square : Shape
square =
    Shape.fromMarks
        [ { x = 0, y = 0, metres = 0 }
        , { x = 10, y = 0, metres = 10 }
        , { x = 10, y = 10, metres = 20 }
        , { x = 0, y = 10, metres = 30 }
        , { x = 0, y = 0, metres = 40 }
        ]


tests : Test
tests =
    describe "Motorsport.Circuit.Shape"
        [ describe "at"
            [ test "a distance past the end of the lap takes it round again" <|
                \_ ->
                    Shape.at 45 square
                        |> Expect.equal { x = 5, y = 0, heading = { x = 1, y = 0 } }
            ]
        ]
