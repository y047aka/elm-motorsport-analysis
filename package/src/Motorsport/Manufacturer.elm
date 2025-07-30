module Motorsport.Manufacturer exposing
    ( Manufacturer(..)
    , fromString, toString
    , toColor
    )

{-|

@docs Manufacturer
@docs fromString, toString
@docs toColor

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
            Color.rgb255 0 144 255

        AstonMartin ->
            -- Aston Martin Racing Green
            Color.rgb255 0 75 45

        BMW ->
            -- BMW Blue/White
            Color.rgb255 0 120 215

        Cadillac ->
            -- Cadillac Black/Gold
            Color.rgb255 20 20 20

        Corvette ->
            -- Classic Corvette Yellow
            Color.rgb255 255 225 0

        Ferrari ->
            -- Ferrari Red
            Color.rgb255 220 20 60

        Ford ->
            -- Ford Blue
            Color.rgb255 0 50 160

        Lexus ->
            -- Lexus Dark Blue
            Color.rgb255 30 30 100

        McLaren ->
            -- McLaren Orange
            Color.rgb255 255 140 0

        Mercedes ->
            -- Mercedes Silver
            Color.rgb255 190 190 190

        Peugeot ->
            -- Peugeot Blue
            Color.rgb255 0 45 100

        Porsche ->
            -- Porsche Silver/Red
            Color.rgb255 180 30 50

        Toyota ->
            -- Toyota Red
            Color.rgb255 235 10 30

        Other ->
            -- Neutral Gray
            Color.rgb255 120 120 120
