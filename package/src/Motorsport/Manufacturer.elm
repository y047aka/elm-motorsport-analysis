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

import Css exposing (Color)
import Css.Color exposing (oklch)


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
            oklch 0.6 0.25 230

        AstonMartin ->
            -- Aston Martin Racing Green
            oklch 0.5 0.25 180

        BMW ->
            -- BMW Blue
            oklch 0.5 0.25 250

        Cadillac ->
            -- Cadillac Gold
            oklch 0.7 0.3 105

        Corvette ->
            -- Classic Corvette Yellow
            oklch 0.7 0.3 105

        Ferrari ->
            -- Ferrari Red
            oklch 0.45 0.25 30

        Ford ->
            -- Ford Blue
            oklch 0.45 0.25 260

        Lexus ->
            -- Lexus Dark Red
            oklch 0.4 0.2 50

        McLaren ->
            -- McLaren Orange
            oklch 0.6 0.25 80

        Mercedes ->
            -- Mercedes Silver
            oklch 0.7 0 0

        Peugeot ->
            -- Peugeot Lime Green
            oklch 0.7 0.25 120

        Porsche ->
            -- Porsche Silver
            oklch 0.8 0 0

        Toyota ->
            -- Toyota Dark Grey
            oklch 0.6 0 0

        Other ->
            -- Neutral Gray
            oklch 0.5 0 0


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


{-| Generate a distinct color based on car number using Oklch color space.
-}
generateCarColor : String -> Color
generateCarColor carNumber =
    let
        carHash =
            String.toInt carNumber |> Maybe.withDefault 0

        hue =
            carHash * 37 |> modBy 360 |> toFloat
    in
    oklch 0.55 0.25 hue
