module Motorsport.Class exposing (Class, fromString, none, toHexColor, toString, toStrokePalette)

import Css
import Css.Color exposing (Color(..), oklch)
import Css.Palette.Svg exposing (SvgPalette, empty)


type Class
    = None
    | LMH
    | LMP1
    | LMP2
    | LMGTE_Pro
    | LMGTE_Am
    | LMGT3
    | InnovativeCar


none : Class
none =
    None


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
    { empty | stroke = ColorValue (toHexColor 2024 class) }


toHexColor : Int -> Class -> Css.Color
toHexColor season class =
    let
        { red, blue, green, orange } =
            { red = oklch 0.628 0.2577 29.23
            , blue = oklch 0.452 0.313214 264.052
            , green = oklch 0.4421 0.1504 142.5
            , orange = oklch 0.6958 0.204259 43.491
            }
    in
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
