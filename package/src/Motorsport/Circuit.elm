module Motorsport.Circuit exposing
    ( Circuit, Layout
    , standard, leMans2025
    , hasMiniSectors
    , Direction(..)
    )

{-|

@docs Circuit, Layout
@docs standard, leMans2025
@docs hasMiniSectors

-}

import Motorsport.Sector exposing (MiniSector(..), Sector(..))


{-| Circuit information
-}
type alias Circuit =
    { name : String
    , direction : Direction
    , layout : Layout
    }


{-| Circuit direction
-}
type Direction
    = Clockwise
    | Counterclockwise


{-| Circuit sector layout
A list of sectors with their associated mini sectors
-}
type alias Layout =
    List ( Sector, List MiniSector )


{-| Standard 3-sector layout (no mini sectors)
-}
standard : Layout
standard =
    [ ( S1, [] ), ( S2, [] ), ( S3, [] ) ]


{-| Le Mans 2025 layout (with mini sectors)
-}
leMans2025 : Layout
leMans2025 =
    [ ( S1, [ SCL2, Z4, IP1 ] )
    , ( S2, [ Z12, SCLC, A7_1, IP2 ] )
    , ( S3, [ A8_1, SCLB, PORIN, POROUT, PITREF, SCL1, FORDOUT, FL ] )
    ]


{-| Check if a layout contains mini sectors
-}
hasMiniSectors : Layout -> Bool
hasMiniSectors layout =
    layout
        |> List.any (\( _, miniSectors ) -> not (List.isEmpty miniSectors))
