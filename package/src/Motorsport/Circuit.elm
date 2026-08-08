module Motorsport.Circuit exposing
    ( Layout
    , Segmentation(..)
    , clockwise, counterClockwise, leMans2025
    )

{-|

@docs Layout
@docs Segmentation
@docs clockwise, counterClockwise, leMans2025

-}

import Motorsport.Circuit.Direction exposing (Direction(..))
import Motorsport.Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector)


{-| How a circuit is laid out for timing. Which way the cars go round is a
property of the circuit, not of any one sector, so it sits beside the divisions
rather than among them.
-}
type alias Layout miniSector =
    { direction : Direction
    , segmentation : Segmentation miniSector
    }


{-| How finely the timing splits a lap of this circuit: every circuit is timed
to three sectors, and Le Mans to fifteen mini-sectors within them as well.

`MiniSectors` carries which sector each mini-sector falls in, and only that.
What order they come in is [`LeMans.all`](Motorsport-Wec-Circuit-LeMans#all)'s to
say.

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
