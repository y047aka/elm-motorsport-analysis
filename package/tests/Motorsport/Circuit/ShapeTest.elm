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
        [ describe "nearest"
            [ test "a place on the line reads as the distance it is marked at" <|
                \_ ->
                    Shape.nearest { x = 10, y = 3 } square
                        |> Expect.all
                            [ .metres >> Expect.equal 13
                            , .distance >> Expect.within (Expect.Absolute 0.0001) 0
                            ]
            , test "the heading is the way the line runs there" <|
                \_ ->
                    Shape.nearest { x = 4, y = 10 } square
                        |> .position
                        |> Expect.equal { x = 4, y = 10, heading = { x = -1, y = 0 } }
            , test "the stretch that closes the lap is part of the line" <|
                \_ ->
                    Shape.nearest { x = -4, y = 6 } square
                        |> Expect.all
                            [ .metres >> Expect.equal 34
                            , .distance >> Expect.equal 4
                            ]
            , test "a place at the finish line reads as the lap's start" <|
                \_ ->
                    -- The line passes here twice over, and the start of it is
                    -- the reading a car crossing the line is given.
                    Shape.nearest { x = -3, y = 0 } square
                        |> Expect.all
                            [ .metres >> Expect.equal 0
                            , .distance >> Expect.equal 3
                            ]
            , test "a place nowhere near the line is answered with how far off it was" <|
                \_ ->
                    Shape.nearest { x = 100, y = -100 } square
                        |> .distance
                        |> Expect.within (Expect.Absolute 0.0001) (sqrt (90 ^ 2 + 100 ^ 2))
            , test "the nearest stretch is the one read, not the first one" <|
                \_ ->
                    Shape.nearest { x = 5, y = 9 } square
                        |> .metres
                        |> Expect.equal 25
            ]
        , describe "at"
            [ test "a distance past the end of the lap takes it round again" <|
                \_ ->
                    Shape.at 45 square
                        |> Expect.equal { x = 5, y = 0, heading = { x = 1, y = 0 } }
            , test "nearest reads back the distance it was placed at" <|
                \_ ->
                    List.range 1 39
                        |> List.map (\metres -> Shape.at (toFloat metres) square)
                        |> List.map (\position -> Shape.nearest { x = position.x, y = position.y } square)
                        |> List.map2 Tuple.pair (List.range 1 39)
                        |> List.filter (\( metres, near ) -> near.metres /= toFloat metres)
                        |> Expect.equal []
            ]
        ]
