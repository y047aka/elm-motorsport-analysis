module Motorsport.TestHelpers.Lap exposing (empty)

{-|

@docs empty

-}

import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Sector as Sector
import Motorsport.TestHelpers.Driver exposing (driverNamed)


{-| A lap with nothing recorded on it, and a driver the fixture picks.
-}
empty : Lap
empty =
    { carNumber = ""
    , driver = driverNamed "Test Driver"
    , lap = 0
    , position = Nothing
    , time = Nothing
    , sectors = Sector.initialize (always { time = Nothing, personalBest = Nothing })
    , best = Nothing
    , elapsed = Instant.raceStart
    , crossing = Lap.NoCrossing
    , flag = Lap.Green
    , miniSectors = Nothing
    }
