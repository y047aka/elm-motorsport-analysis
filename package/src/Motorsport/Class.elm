module Motorsport.Class exposing
    ( Class
    , all
    , compare
    , fromString, toString
    , none
    , toColor
    )

{-|

@docs Class
@docs all
@docs compare
@docs fromString, toString
@docs none
@docs toColor

-}

import Css
import Css.Color exposing (oklch)


{-| The category a car races in.

Opaque: a `Class` only ever comes from [`fromString`](#fromString) or
[`none`](#none), so every value in the app is one the series actually runs.
Ordering goes through [`compare`](#compare) and display through
[`toString`](#toString) -- the constructors are not the interface.

Categories from different eras sit in the same type: `LMGTE Am` ran until 2023
and `LMGT3` replaced it in 2024, so no one season shows both.

-}
type Class
    = None
    | LMH
    | LMP1
    | LMP2
    | LMGTE_Pro
    | LMGTE_Am
    | LMGT3
    | InnovativeCar


{-| Every class a car races in, fastest category first -- the order a
classification lists them in: see [`compare`](#compare).

    List.map toString all
    --> [ "HYPERCAR", "LMP1", "LMP2", "LMGTE Pro", "LMGTE Am", "LMGT3", "INNOVATIVE CAR" ]

[`none`](#none) is not in this list. It stands for a car whose class is unknown,
which is not a category anyone races in.

-}
all : List Class
all =
    [ LMH, LMP1, LMP2, LMGTE_Pro, LMGTE_Am, LMGT3, InnovativeCar ]


{-| The class with no cars in it -- a placeholder for a car whose class is not
known yet.
-}
none : Class
none =
    None


{-| Order classes the way a classification does: the fastest category first,
then down to GT, and cars outside the classification last.

    Maybe.map2 Motorsport.Class.compare (fromString "HYPERCAR") (fromString "LMGT3")
    --> Just LT

`INNOVATIVE CAR` (the Garage 56 entry) races but is not classified, so it sorts
after every class that is. [`none`](#none) sorts after that again.

-}
compare : Class -> Class -> Order
compare a b =
    Basics.compare (toIndex a) (toIndex b)


toIndex : Class -> Int
toIndex class =
    case class of
        LMH ->
            0

        LMP1 ->
            1

        LMP2 ->
            2

        LMGTE_Pro ->
            3

        LMGTE_Am ->
            4

        LMGT3 ->
            5

        InnovativeCar ->
            6

        None ->
            7


{-| Convert a class to the name the series prints for it. For display only --
ordering goes through [`compare`](#compare).

    Maybe.map toString (fromString "LMGTE Pro")
    --> Just "LMGTE Pro"

-}
toString : Class -> String
toString class =
    case class of
        None ->
            "None"

        LMH ->
            "HYPERCAR"

        LMP1 ->
            "LMP1"

        LMP2 ->
            "LMP2"

        LMGTE_Pro ->
            "LMGTE Pro"

        LMGTE_Am ->
            "LMGTE Am"

        LMGT3 ->
            "LMGT3"

        InnovativeCar ->
            "INNOVATIVE CAR"


{-| Read the class name as it appears in the source data.

    fromString "NOT A CLASS"
    --> Nothing

Every name [`toString`](#toString) produces for a class in [`all`](#all) reads
back, but `"None"` does not: [`none`](#none) marks missing data rather than
naming a category, so it cannot be asked for.

-}
fromString : String -> Maybe Class
fromString class =
    case class of
        "HYPERCAR" ->
            Just LMH

        "LMP1" ->
            Just LMP1

        "LMP2" ->
            Just LMP2

        "LMGTE Pro" ->
            Just LMGTE_Pro

        "LMGTE Am" ->
            Just LMGTE_Am

        "LMGT3" ->
            Just LMGT3

        "INNOVATIVE CAR" ->
            Just InnovativeCar

        _ ->
            Nothing


{-| The color a class is drawn in.

The season matters because the palette is reused as the grid changes: `LMGT3`
took over the GT slot in 2024, and it is drawn in the green that `LMGTE Pro`
held while the two categories still ran alongside each other -- so a 2024 GT3
car is orange, like the `LMGTE Am` field it replaced, and a 2025 one is green.

-}
toColor : { season : Int } -> Class -> Css.Color
toColor { season } class =
    case class of
        None ->
            oklch 0 0 0

        LMH ->
            red

        LMP1 ->
            red

        LMP2 ->
            blue

        LMGTE_Pro ->
            green

        LMGTE_Am ->
            orange

        LMGT3 ->
            if season > 2024 then
                green

            else
                orange

        InnovativeCar ->
            blue


red : Css.Color
red =
    oklch 0.5 0.25 29


blue : Css.Color
blue =
    oklch 0.5 0.25 264


green : Css.Color
green =
    oklch 0.5 0.25 142


orange : Css.Color
orange =
    oklch 0.7 0.2 43
