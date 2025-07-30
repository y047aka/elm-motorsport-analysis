module Motorsport.Manufacturer exposing
    ( Manufacturer(..)
    , fromString, toString
    , toColor
    , toColorWithFallback
    )

{-|

@docs Manufacturer
@docs fromString, toString
@docs toColor
@docs toColorWithFallback

-}

import Color exposing (Color)


type Manufacturer
    = Alpine
    | AstonMartin
    | BMW
    | Cadillac
    | Corvette
    | Ferrari
    | Ford
    | Lexus
    | McLaren
    | Mercedes
    | Peugeot
    | Porsche
    | Toyota
    | Other


fromString : String -> Manufacturer
fromString str =
    case str of
        "Alpine" ->
            Alpine

        "Aston Martin" ->
            AstonMartin

        "BMW" ->
            BMW

        "Cadillac" ->
            Cadillac

        "Corvette" ->
            Corvette

        "Ferrari" ->
            Ferrari

        "Ford" ->
            Ford

        "Lexus" ->
            Lexus

        "McLaren" ->
            McLaren

        "Mercedes" ->
            Mercedes

        "Peugeot" ->
            Peugeot

        "Porsche" ->
            Porsche

        "Toyota" ->
            Toyota

        _ ->
            Other


toString : Manufacturer -> String
toString manufacturer =
    case manufacturer of
        Alpine ->
            "Alpine"

        AstonMartin ->
            "Aston Martin"

        BMW ->
            "BMW"

        Cadillac ->
            "Cadillac"

        Corvette ->
            "Corvette"

        Ferrari ->
            "Ferrari"

        Ford ->
            "Ford"

        Lexus ->
            "Lexus"

        McLaren ->
            "McLaren"

        Mercedes ->
            "Mercedes"

        Peugeot ->
            "Peugeot"

        Porsche ->
            "Porsche"

        Toyota ->
            "Toyota"

        Other ->
            "Other"


toColor : Manufacturer -> Color
toColor manufacturer =
    case manufacturer of
        Alpine ->
            -- Alpine Blue
            Color.hsl (210 / 360) 1.0 0.5

        AstonMartin ->
            -- Aston Martin Racing Green
            Color.hsl (150 / 360) 1.0 0.15

        BMW ->
            -- BMW Blue/White
            Color.hsl (207 / 360) 1.0 0.42

        Cadillac ->
            -- Cadillac Black/Gold
            Color.hsl (0 / 360) 0.0 0.08

        Corvette ->
            -- Classic Corvette Yellow
            Color.hsl (53 / 360) 1.0 0.5

        Ferrari ->
            -- Ferrari Red
            Color.hsl (349 / 360) 0.83 0.47

        Ford ->
            -- Ford Blue
            Color.hsl (221 / 360) 1.0 0.31

        Lexus ->
            -- Lexus Dark Blue
            Color.hsl (231 / 360) 0.54 0.25

        McLaren ->
            -- McLaren Orange
            Color.hsl (33 / 360) 1.0 0.5

        Mercedes ->
            -- Mercedes Silver
            Color.hsl (0 / 360) 0.0 0.75

        Peugeot ->
            -- Peugeot Blue
            Color.hsl (213 / 360) 1.0 0.2

        Porsche ->
            -- Porsche Silver/Red
            Color.hsl (350 / 360) 0.71 0.41

        Toyota ->
            -- Toyota Red
            Color.hsl (355 / 360) 0.92 0.48

        Other ->
            -- Neutral Gray
            Color.hsl (0 / 360) 0.0 0.47


{-| Generate color for a manufacturer with car number fallback.
When manufacturer is Other, generates a color based on car number for distinction.
-}
toColorWithFallback : { a | carNumber : String, manufacturer : Manufacturer } -> Color
toColorWithFallback { carNumber, manufacturer } =
    case manufacturer of
        Other ->
            generateCarColor carNumber

        _ ->
            toColor manufacturer


{-| Generate a distinct color based on car number using HSL color space.
-}
generateCarColor : String -> Color
generateCarColor carNumber =
    let
        carHash =
            String.toInt carNumber |> Maybe.withDefault 0

        ( hue, saturation, lightness ) =
            ( carHash * 37 |> modBy 360 |> toFloat
            , 0.7 + (toFloat (carHash * 17 |> modBy 30) / 100)
            , 0.5 + (toFloat (carHash * 13 |> modBy 20) / 100)
            )
    in
    Color.hsl (hue / 360) saturation lightness
