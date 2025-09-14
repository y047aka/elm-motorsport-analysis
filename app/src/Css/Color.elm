module Css.Color exposing (Color(..), currentColor, gray, oklch, transparent)

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
    | Oklch
        { luminance : Float
        , chroma : Float
        , hue : Float
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


oklch : Float -> Float -> Float -> Css.Color
oklch luminance chroma hue =
    let
        valuesList =
            [ numericalPercentageToString luminance
            , String.fromFloat chroma
            , String.fromFloat hue
            ]
    in
    Css.rgb 0 0 0
        |> (\color -> { color | value = "oklch(" ++ String.join " " valuesList ++ ")" })


numericalPercentageToString : Float -> String
numericalPercentageToString value =
    String.fromFloat (value * 100) ++ "%"
