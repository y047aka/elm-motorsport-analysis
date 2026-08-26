module Data.Wec.ManufacturerLogo exposing (url)

{-| Where a manufacturer's logo is served from.

The files sit under `app/public/assets/manufacturer-logos`.

@docs url

-}

import Motorsport.Wec.Manufacturer exposing (Manufacturer(..))


url : Manufacturer -> Maybe String
url manufacturer =
    case manufacturer of
        Alpine ->
            Just "/assets/manufacturer-logos/alpine.png"

        AstonMartin ->
            Just "/assets/manufacturer-logos/aston-martin.png"

        BMW ->
            Just "/assets/manufacturer-logos/bmw.png"

        Cadillac ->
            Just "/assets/manufacturer-logos/cadillac.png"

        Corvette ->
            Just "/assets/manufacturer-logos/corvette.png"

        Ferrari ->
            Just "/assets/manufacturer-logos/ferrari.png"

        Ford ->
            Just "/assets/manufacturer-logos/ford.png"

        Genesis ->
            Just "/assets/manufacturer-logos/genesis.png"

        Lexus ->
            Just "/assets/manufacturer-logos/lexus.png"

        McLaren ->
            Just "/assets/manufacturer-logos/mclaren.png"

        Mercedes ->
            Just "/assets/manufacturer-logos/mercedes.png"

        Peugeot ->
            Just "/assets/manufacturer-logos/peugeot.png"

        Porsche ->
            Just "/assets/manufacturer-logos/porsche.png"

        Toyota ->
            Just "/assets/manufacturer-logos/toyota.png"

        Other ->
            Nothing
