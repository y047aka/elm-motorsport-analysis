module Motorsport.Wec.Class exposing
    ( Class
    , classesOf
    , compare
    , fromString, toString
    , none
    , toColor
    )

{-|

@docs Class
@docs classesOf
@docs compare
@docs fromString, toString
@docs none
@docs toColor

-}

import List.Extra
import Motorsport.Wec.Era as Era exposing (Era)


{-| The category a car races in, as it stood in the era it was read for.

A `Class` carries the order and the color that era gave it, settled once at the
boundary, so [`compare`](#compare) and [`toColor`](#toColor) are plain functions
of the value and nothing downstream needs to know what an era is.

The `index` is a position in the era's grid counted from zero, not the class's
number in a classification: LMGTE Am, the fourth class of 2023, has index 2 on
that season's grid of three.

-}
type Class
    = None
    | Racing { category : Category, index : Int, color : String }


{-| Which category, regardless of era -- only the name it prints depends on it.
-}
type Category
    = Hypercar
    | LMP2
    | LMGTE_Pro
    | LMGTE_Am
    | LMGT3


{-| The class of a car whose class is not known. It raced in no era, so it is
drawn black and sorts after every class that did.
-}
none : Class
none =
    None



-- THE GRID


{-| Every category that raced in an era, in the order a classification lists
them, each with the color it was drawn in.

The single source of era-dependent knowledge: a new era is a case here, a new
season is nothing at all.

-}
grid : Era -> List ( Category, String )
grid era =
    case era of
        Era.GteProAndAm ->
            [ ( Hypercar, red )
            , ( LMP2, blue )
            , ( LMGTE_Pro, green )
            , ( LMGTE_Am, orange )
            ]

        Era.GteAmAsFourthClass ->
            -- Keeping fourth, LMGTE Am kept the orange it already had.
            [ ( Hypercar, red )
            , ( LMP2, blue )
            , ( LMGTE_Am, orange )
            ]

        Era.Gt3AsFourthClass ->
            -- Taking over fourth, LMGT3 took LMGTE Am's orange with it.
            [ ( Hypercar, red )
            , ( LMP2, blue )
            , ( LMGT3, orange )
            ]

        Era.Gt3AsThirdClass ->
            -- Moving up to third, LMGT3 took the green LMGTE Pro had held.
            [ ( Hypercar, red )
            , ( LMP2, blue )
            , ( LMGT3, green )
            ]


{-| Every class a car raced in that era, fastest category first. Never
[`none`](#none), which is not a category anyone races in.
-}
classesOf : Era -> List Class
classesOf era =
    grid era
        |> List.indexedMap
            (\index ( category, color ) ->
                Racing { category = category, index = index, color = color }
            )


{-| Read a class name as it appears in the source data, as of an era. The only
place an era is spent.

A name that era's grid does not list reads as [`none`](#none), rather than a car
given an order and a color it never held.

-}
fromString : Era -> String -> Class
fromString era name =
    classesOf era
        |> List.Extra.find (\class -> toString class == name)
        |> Maybe.withDefault None


{-| The name the series prints for a class, which does not vary by era. For
display only -- ordering goes through [`compare`](#compare).

    toString none
    --> "None"

-}
toString : Class -> String
toString class =
    case class of
        None ->
            "None"

        Racing { category } ->
            categoryToString category


categoryToString : Category -> String
categoryToString category =
    case category of
        Hypercar ->
            "HYPERCAR"

        LMP2 ->
            "LMP2"

        LMGTE_Pro ->
            "LMGTE Pro"

        LMGTE_Am ->
            "LMGTE Am"

        LMGT3 ->
            "LMGT3"


{-| Order classes the way a classification does, fastest category first.

Classes that came in the same position on their own grids -- LMGTE Pro in 2021
and LMGT3 in 2025 -- compare equal, because position is all this compares.

-}
compare : Class -> Class -> Order
compare a b =
    case ( a, b ) of
        ( Racing x, Racing y ) ->
            Basics.compare x.index y.index

        ( Racing _, None ) ->
            LT

        ( None, Racing _ ) ->
            GT

        ( None, None ) ->
            EQ


{-| The color a class was drawn in, in its own era.
-}
toColor : Class -> String
toColor class =
    case class of
        Racing { color } ->
            color

        None ->
            oklch 0 0 0


red : String
red =
    oklch 0.5 0.25 29


blue : String
blue =
    oklch 0.5 0.25 264


green : String
green =
    oklch 0.5 0.25 142


orange : String
orange =
    oklch 0.7 0.2 43


oklch : Float -> Float -> Float -> String
oklch luminance chroma hue =
    "oklch(" ++ String.fromFloat (luminance * 100) ++ "% " ++ String.fromFloat chroma ++ " " ++ String.fromFloat hue ++ ")"
