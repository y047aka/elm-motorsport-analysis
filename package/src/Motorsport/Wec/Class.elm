module Motorsport.Wec.Class exposing (grid)

{-|

@docs grid

-}

import Motorsport.Class as Class
import Motorsport.Wec.Era as Era exposing (Era)


{-| Every class that era ran, in the order a classification lists them, each
with the color it is drawn in.

The single source of era-dependent knowledge: a new era is a case here, a new
season is nothing at all.

The colors follow the places and not the categories, which is why 2023's LMGTE
Am is third in the order and orange all the same -- green belongs to the place
LMGTE Pro left, and that place stood empty.

-}
grid : Era -> Class.Grid
grid era =
    case era of
        Era.GteProAndAm ->
            [ { name = "HYPERCAR", color = red }
            , { name = "LMP2", color = blue }
            , { name = "LMGTE Pro", color = green }
            , { name = "LMGTE Am", color = orange }
            ]

        Era.GteAmAsFourthClass ->
            [ { name = "HYPERCAR", color = red }
            , { name = "LMP2", color = blue }
            , { name = "LMGTE Am", color = orange }
            ]

        Era.Gt3AsFourthClass ->
            [ { name = "HYPERCAR", color = red }
            , { name = "LMP2", color = blue }
            , { name = "LMGT3", color = orange }
            ]

        Era.Gt3AsThirdClass ->
            [ { name = "HYPERCAR", color = red }
            , { name = "LMP2", color = blue }
            , { name = "LMGT3", color = green }
            ]


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
