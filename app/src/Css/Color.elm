module Css.Color exposing (Color(..), currentColor, gray, transparent)

import Css


type Color
    = ColorValue
        -- Css.Colorと同じだが、lamderaの型推論が上手くいかないため、プロティを直接記述している
        { red : Int
        , green : Int
        , blue : Int
        , alpha : Float
        , value : String
        , color : Css.Compatible
        }
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
    ColorValue (Css.hex "#eee")
