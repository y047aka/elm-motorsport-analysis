module Motorsport.Circuit exposing
    ( Circuit, Layout
    , clockwise, counterClockwise, leMans2025
    , hasMiniSectors
    , sectorDefaultRatio
    )

{-|

@docs Circuit, Layout
@docs clockwise, counterClockwise, leMans2025
@docs hasMiniSectors
@docs sectorDefaultRatio

-}

import Motorsport.Circuit.Direction exposing (Direction(..))
import Motorsport.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector)
import Motorsport.Sector as Sector exposing (BySector)


{-| Circuit information
-}
type alias Circuit miniSector =
    { name : String
    , layout : Layout miniSector
    }


{-| Circuit sector layout
Generic layout type that can represent any circuit configuration
The miniSector type parameter allows different circuits to use their specific mini sector types

Which way the cars go round is a property of the circuit, not of any one sector,
so it sits beside the sectors rather than among them.

-}
type alias Layout miniSector =
    { direction : Direction
    , sectors : BySector (List miniSector)
    }


{-| Clockwise 3-sector layout (no mini sectors)
-}
clockwise : Layout miniSector
clockwise =
    { direction = Clockwise
    , sectors = Sector.initialize (always [])
    }


{-| Counter-clockwise 3-sector layout (no mini sectors)
-}
counterClockwise : Layout miniSector
counterClockwise =
    { direction = CounterClockwise
    , sectors = Sector.initialize (always [])
    }


{-| Le Mans 2025 layout (with mini sectors)
-}
leMans2025 : Layout LeMans2025MiniSector
leMans2025 =
    LeMans.layout


{-| Check if a layout contains mini sectors
-}
hasMiniSectors : Layout miniSector -> Bool
hasMiniSectors { sectors } =
    Sector.values sectors |> List.all (List.isEmpty >> not)


{-| Get the default ratio for a specific sector
-}
sectorDefaultRatio : Float
sectorDefaultRatio =
    1 / 3
