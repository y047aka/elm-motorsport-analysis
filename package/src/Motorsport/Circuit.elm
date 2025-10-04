module Motorsport.Circuit exposing
    ( Circuit, Layout
    , standard, leMans2025
    , hasMiniSectors
    , sectorDefaultRatio
    )

{-|

@docs Circuit, Layout
@docs standard, leMans2025
@docs hasMiniSectors

@docs sectorDefaultRatio

-}

import Motorsport.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector)
import Motorsport.Sector exposing (Sector(..))


{-| Circuit information
-}
type alias Circuit miniSector =
    { name : String
    , layout : Layout miniSector
    }


{-| Circuit sector layout
Generic layout type that can represent any circuit configuration
The miniSector type parameter allows different circuits to use their specific mini sector types
-}
type alias Layout miniSector =
    List ( Sector, List miniSector )


{-| Standard 3-sector layout (no mini sectors)
-}
standard : Layout miniSector
standard =
    [ ( S1, [] ), ( S2, [] ), ( S3, [] ) ]


{-| Le Mans 2025 layout (with mini sectors)
-}
leMans2025 : Layout LeMans2025MiniSector
leMans2025 =
    LeMans.layout


{-| Check if a layout contains mini sectors
-}
hasMiniSectors : Layout miniSector -> Bool
hasMiniSectors layout =
    layout
        |> List.all (\( _, miniSectors ) -> not (List.isEmpty miniSectors))


{-| Get the default ratio for a specific sector
-}
sectorDefaultRatio : Float
sectorDefaultRatio =
    1 / 3
