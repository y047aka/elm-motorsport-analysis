module Motorsport.Class exposing
    ( Class
    , Grid
    , classesOf
    , compare
    , fromString, toString
    , none
    , toColor
    )

{-|

@docs Class
@docs Grid
@docs classesOf
@docs compare
@docs fromString, toString
@docs none
@docs toColor

-}

import List.Extra


{-| The class a car races in: the name it goes by, the position a
classification lists it in, and the color it is drawn in.

The position and the color come from the grid the class was read against, so a
name placed or colored differently by another grid is a different value, and
the same name read against one grid twice is one value.

-}
type Class
    = None
    | Racing { name : String, order : Int, color : String }


{-| A series' classes: the names cars race under, in the order a classification
lists them, each with the color it is drawn in.

Which names and colors belong to which season is the series' own knowledge --
[`Wec.Class`](Motorsport-Wec-Class#grid) supplies WEC's, and a class is only
ever built off a grid.

-}
type alias Grid =
    List { name : String, color : String }


{-| The class of a car whose class is not known. It is on no grid, so it is
drawn black and sorts after every class that is.
-}
none : Class
none =
    None


{-| Every class a grid lists, in the order it lists them. Never
[`none`](#none), which no series lists a car under.
-}
classesOf : Grid -> List Class
classesOf grid =
    List.indexedMap (\order { name, color } -> Racing { name = name, order = order, color = color }) grid


{-| Read a class name as it appears in the source data, against a grid.

A name that grid does not list reads as [`none`](#none), rather than a car
given an order and a color it never held.

-}
fromString : Grid -> String -> Class
fromString grid name =
    classesOf grid
        |> List.Extra.find (\class -> toString class == name)
        |> Maybe.withDefault None


{-| The name the series prints for a class, which is the name its grid lists.
For display only -- ordering goes through [`compare`](#compare).

    toString none
    --> "None"

-}
toString : Class -> String
toString class =
    case class of
        None ->
            "None"

        Racing { name } ->
            name


{-| Order classes the way a classification does, the head of the grid first.

Classes that came in the same position on their own grids -- a class third on
one grid and a class third on another -- compare equal, because position is all
this compares.

-}
compare : Class -> Class -> Order
compare a b =
    case ( a, b ) of
        ( Racing x, Racing y ) ->
            Basics.compare x.order y.order

        ( Racing _, None ) ->
            LT

        ( None, Racing _ ) ->
            GT

        ( None, None ) ->
            EQ


{-| The color a class was drawn in, on the grid it was read from.
-}
toColor : Class -> String
toColor class =
    case class of
        Racing { color } ->
            color

        None ->
            black


black : String
black =
    "oklch(0% 0 0)"
