module Data.Wec.Class exposing (Class, fromString, toString, toStrokePalette)

import Css
import Css.Color exposing (Color(..))
import Css.Palette.Svg exposing (SvgPalette, empty)


type Class
    = LMH
    | LMP1
    | LMP2
    | LMGTE_Pro
    | LMGTE_Am
    | LMGT3
    | InnovativeCar


toString : Class -> String
toString class =
    case class of
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


toStrokePalette : Class -> SvgPalette
toStrokePalette class =
    { empty | stroke = ColorValue (toHexColor class) }


toHexColor : Class -> Css.Color
toHexColor class =
    case class of
        LMH ->
            Css.hex "#f00"

        LMP1 ->
            Css.hex "#f00"

        LMP2 ->
            Css.hex "#00f"

        LMGTE_Pro ->
            Css.hex "#060"

        LMGTE_Am ->
            Css.hex "#f60"

        LMGT3 ->
            Css.hex "#f60"

        InnovativeCar ->
            Css.hex "#00f"
