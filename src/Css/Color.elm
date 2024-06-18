module Css.Color exposing (Color(..), currentColor, gray, transparent)

import Css


type Color
    = ColorValue Css.Color
    | CurrentColor
    | Transparent


currentColor : Color
currentColor =
    CurrentColor


transparent : Color
transparent =
    Transparent


gray : Color
gray =
    ColorValue (Css.hex "#999")
