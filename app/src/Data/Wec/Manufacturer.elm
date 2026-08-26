module Data.Wec.Manufacturer exposing (fromName)

{-| Which manufacturers the timing feed names, and how each is drawn.

The logos sit under `app/public/assets/manufacturer-logos`.

@docs fromName

-}

import Css exposing (Color)
import Css.Color exposing (oklch)
import Motorsport.Manufacturer exposing (Manufacturer, unknown)


{-| `carNumber` is what tells the cars of an unnamed manufacturer apart.
-}
fromName : { name : String, carNumber : String } -> Manufacturer
fromName { name, carNumber } =
    case name of
        "Alpine" ->
            -- Alpine Blue
            known name (oklch 0.6 0.25 230) "alpine"

        "Aston Martin" ->
            -- Aston Martin Racing Green
            known name (oklch 0.5 0.25 180) "aston-martin"

        "BMW" ->
            -- BMW Blue
            known name (oklch 0.5 0.25 250) "bmw"

        "Cadillac" ->
            -- Cadillac Gold
            known name (oklch 0.7 0.3 105) "cadillac"

        "Corvette" ->
            -- Classic Corvette Yellow
            known name (oklch 0.7 0.3 105) "corvette"

        "Ferrari" ->
            -- Ferrari Red
            known name (oklch 0.45 0.25 30) "ferrari"

        "Ford" ->
            -- Ford Blue
            known name (oklch 0.45 0.25 260) "ford"

        "Genesis" ->
            known name (oklch 0.6 0 0) "genesis"

        "Lexus" ->
            -- Lexus Dark Red
            known name (oklch 0.4 0.2 50) "lexus"

        "McLaren" ->
            -- McLaren Orange
            known name (oklch 0.6 0.25 80) "mclaren"

        "Mercedes" ->
            -- Mercedes Silver
            known name (oklch 0.7 0 0) "mercedes"

        "Peugeot" ->
            -- Peugeot Lime Green
            known name (oklch 0.7 0.25 120) "peugeot"

        "Porsche" ->
            -- Porsche Silver
            known name (oklch 0.8 0 0) "porsche"

        "Toyota" ->
            -- Toyota Dark Grey
            known name (oklch 0.6 0 0) "toyota"

        _ ->
            { unknown
                | name = name
                , chartColor = generatedColor carNumber
            }


known : String -> Color -> String -> Manufacturer
known name color logo =
    { name = name
    , color = color
    , chartColor = color
    , logoUrl = Just ("/assets/manufacturer-logos/" ++ logo ++ ".png")
    }


generatedColor : String -> Color
generatedColor carNumber =
    let
        carHash =
            String.toInt carNumber |> Maybe.withDefault 0

        hue =
            carHash * 37 |> modBy 360 |> toFloat
    in
    oklch 0.55 0.25 hue
