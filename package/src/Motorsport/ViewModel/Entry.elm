module Motorsport.ViewModel.Entry exposing
    ( Entry
    , CurrentSectorStates
    , ClassInfo, classInfoOf
    )

{-| One car's line on the timing screen at one moment of the race.

This is what the view layer is actually made of, which is why it lives apart from
the computation in [`Standings`](Motorsport-ViewModel-Standings) that produces it.

Everything here is already worked out. An entry holds no laps and no clock -- the
rating, the gaps, the sector progress were all settled when the standings were
computed, so a view can render one without knowing where it came from.

@docs Entry
@docs CurrentSectorStates
@docs ClassInfo, classInfoOf

-}

import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap exposing (Gap)
import Motorsport.Lap as Lap exposing (MiniSectors)
import Motorsport.Lap.Performance exposing (MiniSectorPerformance, RatedTime, SectorPerformance)
import Motorsport.Race.Car as Car
import Motorsport.Sector exposing (BySector)
import Motorsport.Status exposing (Status)


type alias Entry =
    { position : Int
    , positionInClass : Int
    , status : Status
    , metadata : Car.Metadata

    -- A raw CSS color string; see ClassInfo.color.
    , classColor : String
    , lapsCompleted : Int
    , currentLapTime : Maybe Duration
    , currentLapBest : Maybe Duration

    -- currentLapSectors holds raw times (for data display such as the Debug page).
    -- currentLapSectorStates is the single source of truth for progress and performance rating.
    , currentLapSectors : Maybe Lap.SectorTimes
    , currentLapSectorStates : Maybe CurrentSectorStates
    , currentLapMiniSectors : Maybe MiniSectors
    , currentLapElapsed : Duration
    , currentLapRated : Maybe RatedTime
    , sector : Maybe Lap.SectorProgress
    , miniSector : Maybe Lap.MiniSectorProgress
    , gapToLeader : Gap
    , intervalToAhead : Gap
    , currentLapProgress : Float
    , lastLapRated : Maybe RatedTime
    , bestLapRated : Maybe RatedTime
    , lastLapSectors : Maybe SectorPerformance
    , lastLapMiniSectors : Maybe MiniSectorPerformance
    , currentDriver : Maybe Driver
    }


{-| Per-sector "progress + performance rating" for the current lap.
Rated at compute time so donut displays can render without being supplied BestTimes separately.

`rated` is `Nothing` for a sector the source data has no time for, the same way
a mini-sector's is; there is nothing to colour it by.

-}
type alias CurrentSectorStates =
    BySector { progress : Float, rated : Maybe RatedTime }


{-| Display info needed by class headers and badges.
The color is settled when the class is decoded; see `Motorsport.Class`.
-}
type alias ClassInfo =
    { class : Class
    , name : String

    -- A raw CSS color string rather than Css.Color: every consumer feeds
    -- this straight into a raw string sink (Svg fill, Css.property
    -- "background-color"), so storing the extracted value avoids
    -- re-extracting it at each call site.
    , color : String
    }


{-| Extracts a class's display info from an entry.
-}
classInfoOf : Entry -> ClassInfo
classInfoOf entry =
    { class = entry.metadata.class
    , name = Class.toString entry.metadata.class
    , color = entry.classColor
    }
