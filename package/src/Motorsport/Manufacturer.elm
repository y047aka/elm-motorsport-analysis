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
            Color.hsl (210 / 360) 1 0.5

        AstonMartin ->
            -- Aston Martin Racing Green
            Color.hsl (170 / 360) 0.8 0.35

        BMW ->
            -- BMW Blue
            Color.hsl (220 / 360) 1 0.5

        Cadillac ->
            -- Cadillac Gold
            Color.hsl (45 / 360) 1 0.45

        Corvette ->
            -- Classic Corvette Yellow
            Color.hsl (50 / 360) 1 0.5

        Ferrari ->
            -- Ferrari Red
            Color.hsl (0 / 360) 0.85 0.4

        Ford ->
            -- Ford Blue
            Color.hsl (230 / 360) 1 0.5

        Lexus ->
            -- Lexus Dark Blue
            Color.hsl (0 / 360) 0.55 0.4

        McLaren ->
            -- McLaren Orange
            Color.hsl (30 / 360) 1 0.45

        Mercedes ->
            -- Mercedes Silver
            Color.hsl 0 0 0.6

        Peugeot ->
            -- Peugeot Lime Green
            Color.hsl (75 / 360) 0.9 0.45

        Porsche ->
            -- Porsche Silver
            Color.hsl 0 0 0.8

        Toyota ->
            -- Toyota Dark Grey
            Color.hsl 0 0 0.5

        Other ->
            -- Neutral Gray
            Color.hsl (0 / 360) 0 0.47


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
