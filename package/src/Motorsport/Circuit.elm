module Motorsport.Circuit exposing
    ( Circuit, Layout
    , Segmentation(..)
    , clockwise, counterClockwise, leMans2025
    , sectorDefaultRatio
    )

{-|

@docs Circuit, Layout
@docs Segmentation
@docs clockwise, counterClockwise, leMans2025
@docs sectorDefaultRatio

-}

import Motorsport.Circuit.Direction exposing (Direction(..))
import Motorsport.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector)
import Motorsport.Sector exposing (BySector)


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
    , segmentation : Segmentation miniSector
    }


{-| How finely the timing splits a lap of this circuit.

Every circuit is timed to three sectors; Le Mans is timed to fifteen
mini-sectors within them as well. The two used to be told apart by whether the
per-sector lists of mini-sectors were empty, which left "all three empty" and
"all three full" as the only meaningful arrangements of a type that admitted
eight, and a caller asking which it had counting empty lists to find out.

`MiniSectors` carries the grouping because that is the only thing the grouping
is for: which sector a mini-sector falls in. What order they come in is
[`LeMans.all`](Motorsport-Circuit-LeMans#all)'s to say, and the two agree --
see `LeMansTest`.

-}
type Segmentation miniSector
    = SectorsOnly
    | MiniSectors (BySector (List miniSector))


{-| Clockwise 3-sector layout (no mini sectors)
-}
clockwise : Layout miniSector
clockwise =
    { direction = Clockwise
    , segmentation = SectorsOnly
    }


{-| Counter-clockwise 3-sector layout (no mini sectors)
-}
counterClockwise : Layout miniSector
counterClockwise =
    { direction = CounterClockwise
    , segmentation = SectorsOnly
    }


{-| Le Mans 2025 layout (with mini sectors)
-}
leMans2025 : Layout LeMans2025MiniSector
leMans2025 =
    { direction = LeMans.layout.direction
    , segmentation = MiniSectors LeMans.layout.sectors
    }


{-| What share of the lap a sector takes when no lap has set a time to measure
it by -- the counterpart of
[`LeMans.defaultRatio`](Motorsport-Circuit-LeMans#defaultRatio), and an even
third because three sectors is all the timing says about a circuit that records
no mini-sectors.
-}
sectorDefaultRatio : Float
sectorDefaultRatio =
    1 / 3
