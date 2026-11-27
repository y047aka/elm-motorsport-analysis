module Motorsport.ClassTest exposing (tests)

import Expect
import List.Extra
import Motorsport.Class as Class exposing (Class)
import Test exposing (..)


tests : Test
tests =
    describe "Motorsport.Class"
        [ describe "compare"
            [ test "orders each grid the way it lists its classes" <|
                \_ ->
                    grids
                        |> List.map
                            (\grid ->
                                List.sortWith Class.compare (List.reverse (Class.classesOf grid))
                            )
                        |> Expect.equalLists (List.map Class.classesOf grids)
            , test "is reflexive" <|
                \_ ->
                    everyClass
                        |> List.map (\class -> Class.compare class class)
                        |> List.filter ((/=) EQ)
                        |> Expect.equalLists []
            , test "is antisymmetric" <|
                \_ ->
                    pairs everyClass
                        |> List.map (\( a, b ) -> ( Class.compare a b, Class.compare b a ))
                        |> List.filter (\( ab, ba ) -> ab /= flip ba)
                        |> Expect.equalLists []
            , test "sorts `none` after every class a grid lists" <|
                \_ ->
                    everyRacingClass
                        |> List.map (\class -> Class.compare class Class.none)
                        |> List.filter ((/=) LT)
                        |> Expect.equalLists []
            , test "calls two classes of one grid equal when they came the same place" <|
                \_ ->
                    -- Beta is second on `alphaFirst`; Gamma is second on
                    -- `alphaSecond`. Place is all compare looks at.
                    Class.compare beta gamma
                        |> Expect.equal EQ
            , test "never calls two classes of one grid equal" <|
                \_ ->
                    grids
                        |> List.concatMap
                            (\grid ->
                                pairs (Class.classesOf grid)
                                    |> List.filter (\( a, b ) -> a /= b && Class.compare a b == EQ)
                            )
                        |> Expect.equalLists []
            ]
        , describe "classesOf"
            [ test "is the grid, in the order it lists its classes" <|
                \_ ->
                    grids
                        |> List.map (Class.classesOf >> List.map Class.toString)
                        |> Expect.equalLists
                            [ [ "Alpha", "Beta", "Gamma" ]
                            , [ "Alpha", "Gamma" ]
                            ]
            , test "never lists `none`, which no series lists a car under" <|
                \_ ->
                    grids
                        |> List.filter (\grid -> List.member Class.none (Class.classesOf grid))
                        |> Expect.equalLists []
            ]
        , describe "fromString"
            [ test "reads back every name `toString` prints for the grid's own classes" <|
                \_ ->
                    grids
                        |> List.map
                            (\grid ->
                                Class.classesOf grid
                                    |> List.map (Class.toString >> Class.fromString grid)
                            )
                        |> Expect.equalLists (List.map Class.classesOf grids)
            , test "reads a name another grid lists as `none`" <|
                \_ ->
                    -- Beta races under `alphaFirst`; a file read against
                    -- `alphaSecond` has no Beta to settle an order and a color on.
                    Class.fromString alphaSecond "Beta"
                        |> Expect.equal Class.none
            , test "reads that same name as a class in the grid that lists it" <|
                \_ ->
                    Class.fromString alphaFirst "Beta"
                        |> Expect.notEqual Class.none
            , test "settles order and color, so the same name reads differently in two grids" <|
                \_ ->
                    -- Gamma is third on `alphaFirst` and second on `alphaSecond`.
                    Class.fromString alphaFirst "Gamma"
                        |> Expect.notEqual (Class.fromString alphaSecond "Gamma")
            , test "reads the name of `none` back as `none`" <|
                \_ ->
                    grids
                        |> List.map (\grid -> Class.fromString grid (Class.toString Class.none))
                        |> List.filter ((/=) Class.none)
                        |> Expect.equalLists []
            , test "reads a name no class goes by as `none`" <|
                \_ ->
                    Class.fromString alphaFirst "Delta"
                        |> Expect.equal Class.none
            ]
        , describe "toString"
            [ test "keeps a class's name wherever it is listed" <|
                \_ ->
                    [ Class.fromString alphaFirst "Gamma", Class.fromString alphaSecond "Gamma" ]
                        |> List.map Class.toString
                        |> Expect.equalLists [ "Gamma", "Gamma" ]
            , test "names the class nobody knows `None`" <|
                \_ ->
                    Class.toString Class.none
                        |> Expect.equal "None"
            ]
        , describe "toColor"
            [ test "draws a class in the color its own grid gives it" <|
                \_ ->
                    [ Class.toColor beta, Class.toColor gamma ]
                        |> Expect.equalLists [ blue, orange ]
            , test "draws the class nobody knows black" <|
                \_ ->
                    Class.toColor Class.none
                        |> Expect.equal "oklch(0% 0 0)"
            , test "gives each class on a grid a color of its own" <|
                \_ ->
                    let
                        colors =
                            Class.classesOf alphaFirst
                                |> List.map Class.toColor
                    in
                    List.Extra.unique colors
                        |> Expect.equalLists colors
            ]
        ]


{-| Two grids, so every law is checked in more than one arrangement.
-}
grids : List Class.Grid
grids =
    [ alphaFirst, alphaSecond ]


alphaFirst : Class.Grid
alphaFirst =
    [ { name = "Alpha", color = red }
    , { name = "Beta", color = blue }
    , { name = "Gamma", color = green }
    ]


alphaSecond : Class.Grid
alphaSecond =
    [ { name = "Alpha", color = red }
    , { name = "Gamma", color = orange }
    ]


{-| Every class any grid here lists. A class that moved or was recolored
appears once per grid it appeared on, since that is what makes two `Class`
values differ.
-}
everyRacingClass : List Class
everyRacingClass =
    List.Extra.unique (List.concatMap Class.classesOf grids)


{-| The racing classes plus `none` -- ordering has to hold for the placeholder
too, and no grid lists it.
-}
everyClass : List Class
everyClass =
    Class.none :: everyRacingClass


beta : Class
beta =
    Class.fromString alphaFirst "Beta"


gamma : Class
gamma =
    Class.fromString alphaSecond "Gamma"


red : String
red =
    "oklch(50% 0.25 29)"


blue : String
blue =
    "oklch(50% 0.25 264)"


green : String
green =
    "oklch(50% 0.25 142)"


orange : String
orange =
    "oklch(70% 0.2 43)"


{-| Every ordered pair, including each element with itself.
-}
pairs : List a -> List ( a, a )
pairs xs =
    List.concatMap (\a -> List.map (Tuple.pair a) xs) xs


flip : Order -> Order
flip order =
    case order of
        LT ->
            GT

        EQ ->
            EQ

        GT ->
            LT
