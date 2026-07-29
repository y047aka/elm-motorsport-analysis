module Css.Color exposing (Color(..), oklch, transparent)

import Css


type Color
    = ColorValue Css.Color
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


transparent : Color
transparent =
    Transparent


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
