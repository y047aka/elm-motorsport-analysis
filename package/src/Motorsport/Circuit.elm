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
    { s1 : List miniSector
    , s2 : List miniSector
    , s3 : List miniSector
    }


{-| Standard 3-sector layout (no mini sectors)
-}
standard : Layout miniSector
standard =
    { s1 = [], s2 = [], s3 = [] }


{-| Le Mans 2025 layout (with mini sectors)
-}
leMans2025 : Layout LeMans2025MiniSector
leMans2025 =
    LeMans.layout


{-| Check if a layout contains mini sectors
-}
hasMiniSectors : Layout miniSector -> Bool
hasMiniSectors { s1, s2, s3 } =
    not (List.isEmpty s1) && not (List.isEmpty s2) && not (List.isEmpty s3)


{-| Get the default ratio for a specific sector
-}
sectorDefaultRatio : Float
sectorDefaultRatio =
    1 / 3
