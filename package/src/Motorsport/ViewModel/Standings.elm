module Motorsport.ViewModel.Standings exposing
    ( Standings
    , compute, fromLaps, fromList
    , toList, toClassList, leader, lapCount, elapsed
    , groupCarsByCloseIntervals
    )

{-| The whole timing screen at one moment of the race.

What a single line of it looks like is [`Entry`](Motorsport-ViewModel-Entry);
this module is how one gets built and read back.

The race itself is read by [`Race.Snapshot`](Motorsport-Race-Snapshot), which
settles what each car is doing, who is ahead of whom, and the gaps between them.
This module renders that: it rates the times against the race's record and works
out the progress the displays draw.

@docs Standings
@docs compute, fromLaps, fromList

@docs toList, toClassList, leader, lapCount, elapsed

@docs groupCarsByCloseIntervals

-}

import List.Extra
import Motorsport.BestTimes as BestTimes
import Motorsport.Class as Class
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (SectorPerformance)
import Motorsport.Ordering as Ordering exposing (ByPosition)
import Motorsport.Race exposing (Race)
import Motorsport.Race.Car as Car
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Sector as Sector
import Motorsport.Status as Status
import Motorsport.ViewModel.Entry as Entry exposing (ClassInfo, CurrentSectorStates, Entry)
import SortedList exposing (SortedList)


type Standings
    = Standings
        { elapsed : Instant
        , lapCount : Int
        , entries : SortedList ByPosition Entry

        -- Plain lists here (already position-sorted by construction, see
        -- groupEntriesByClass): consumers of toClassList only ever render
        -- these entries, never re-sort them, so the phantom-typed SortedList
        -- guarantee isn't worth the extra unwrapping at each call site.
        , entriesByClass : List ( ClassInfo, List Entry )
        }


{-| Read the race at a moment of it, then turn what the cars are doing into
lines the view can render.

Everything a line says about the race -- what the car is doing, where it stands,
how far behind it is, how its times rate -- is
[`Race.Snapshot`](Motorsport-Race-Snapshot)'s. What is left here is the drawing:
the class's colour, and the fractions a donut and a track marker are filled to.

-}
compute : BestTimes.Snapshot -> { elapsed : Instant } -> Race -> Standings
compute bestTimes clock race =
    let
        snapshot =
            Snapshot.at bestTimes clock race

        entries =
            Snapshot.toList snapshot
                |> List.map entryOf

        sortedEntries =
            Ordering.byPosition entries
    in
    Standings
        { elapsed = Snapshot.elapsed snapshot
        , lapCount = Snapshot.lapCount snapshot
        , entries = sortedEntries
        , entriesByClass = groupEntriesByClass sortedEntries
        }


entryOf : CarAt -> Entry
entryOf car =
    let
        metadata =
            car.metadata

        lastLap =
            Maybe.withDefault Lap.empty car.lastLap

        currentLap =
            car.currentLap
    in
    { position = car.position
    , positionInClass = car.positionInClass
    , status = car.status
    , metadata = metadata
    , classColor = (Class.toColor metadata.class).value
    , lapsCompleted = lastLap.lap
    , currentLapTime = currentLap |> Maybe.andThen .time
    , currentLapBest = currentLap |> Maybe.andThen .best
    , currentLapSectors = currentLap |> Maybe.map .sectors
    , currentLapSectorStates =
        car.currentLapSectorsRated
            |> Maybe.map (currentSectorStates car.sector)
    , currentLapMiniSectors = currentLap |> Maybe.andThen .miniSectors
    , currentLapElapsed = car.currentLapElapsed
    , currentLapRated = car.currentLapRated
    , sector = car.sector
    , miniSector = car.miniSector
    , gapToLeader = car.gapToLeader
    , intervalToAhead = car.intervalToAhead
    , currentLapProgress =
        currentLap
            |> Maybe.andThen .time
            |> Maybe.map (\lapTime -> min 1.0 (toFloat car.currentLapElapsed / toFloat lapTime))
            |> Maybe.withDefault 0
    , lastLapRated = car.lastLapRated
    , bestLapRated = car.bestLapRated
    , lastLapSectors = car.lastLapSectorsRated
    , lastLapMiniSectors = car.lastLapMiniSectorsRated
    , currentDriver = car.currentDriver
    }


{-| For debugging: builds a Standings from a single car's lap list.

Treats each lap as one Entry, setting `metadata.carNumber` to the lap-number string.

-}
fromLaps : Car.Metadata -> List Lap -> Standings
fromLaps baseMetadata laps =
    let
        bestTimes =
            BestTimes.final (BestTimes.fromLaps laps)

        fastestLapTime =
            BestTimes.timeOf bestTimes.fastestLapTime

        entries =
            laps
                |> List.indexedMap
                    (\index lap ->
                        { position = index + 1
                        , positionInClass = index + 1
                        , status = Status.Racing
                        , metadata = { baseMetadata | carNumber = String.fromInt lap.lap }
                        , classColor = (Class.toColor baseMetadata.class).value
                        , lapsCompleted = lap.lap
                        , currentLapTime = lap.time
                        , currentLapBest = lap.best
                        , currentLapSectors = Just lap.sectors
                        , currentLapSectorStates = Just (currentSectorStates Nothing (Performance.ofSectors bestTimes lap))
                        , currentLapMiniSectors = lap.miniSectors
                        , currentLapElapsed = 0
                        , currentLapRated = Nothing
                        , sector = Nothing
                        , miniSector = Nothing
                        , gapToLeader = Gap.none
                        , intervalToAhead = Gap.none
                        , currentLapProgress = 0
                        , lastLapRated =
                            Performance.rateTime fastestLapTime { time = lap.time, personalBest = lap.best }
                        , bestLapRated =
                            Performance.rateTime fastestLapTime { time = lap.best, personalBest = lap.best }
                        , lastLapSectors = Just (Performance.ofSectors bestTimes lap)
                        , lastLapMiniSectors = Performance.ofMiniSectors bestTimes lap
                        , currentDriver = Just lap.driver
                        }
                    )

        sortedEntries =
            Ordering.byPosition entries
    in
    Standings
        { elapsed = Instant.raceStart
        , lapCount = laps |> List.map .lap |> List.maximum |> Maybe.withDefault 0
        , entries = sortedEntries
        , entriesByClass = groupEntriesByClass sortedEntries
        }


{-| Builds a Standings from a list of `Entry`. Used to specify entries directly, e.g. in tests.
-}
fromList : List Entry -> Standings
fromList entries =
    let
        sortedEntries =
            Ordering.byPosition entries
    in
    Standings
        { elapsed = Instant.raceStart
        , lapCount = entries |> List.map .lapsCompleted |> List.maximum |> Maybe.withDefault 0
        , entries = sortedEntries
        , entriesByClass = groupEntriesByClass sortedEntries
        }


groupEntriesByClass : SortedList ByPosition Entry -> List ( ClassInfo, List Entry )
groupEntriesByClass sortedEntries =
    sortedEntries
        |> SortedList.gatherEqualsBy (.metadata >> .class)
        |> List.map (\( first, rest ) -> ( Entry.classInfoOf first, first :: SortedList.toList rest ))


{-| How full each sector's donut is drawn, laid over the ratings that colour it.

The rating is the race's; how far round the arc goes is this layer's only
addition to it.

-}
currentSectorStates : Maybe Lap.SectorProgress -> SectorPerformance -> CurrentSectorStates
currentSectorStates sectorProgress rated =
    let
        -- Sectors already driven through are complete, the ones ahead
        -- untouched; no sector in progress at all means the lap is over.
        progressOf sector =
            case sectorProgress of
                Just current ->
                    case Sector.compare sector current.sector of
                        LT ->
                            1

                        EQ ->
                            current.progress

                        GT ->
                            0

                Nothing ->
                    1
    in
    Sector.map2 (\progress rating -> { progress = progress, rated = rating })
        (Sector.initialize progressOf)
        rated


toList : Standings -> List Entry
toList (Standings s) =
    SortedList.toList s.entries


toClassList : Standings -> List ( ClassInfo, List Entry )
toClassList (Standings s) =
    s.entriesByClass


leader : Standings -> Maybe Entry
leader (Standings s) =
    SortedList.head s.entries


lapCount : Standings -> Int
lapCount (Standings s) =
    s.lapCount


{-| The moment of the race this Standings represents; the clock passed to compute is baked in.
-}
elapsed : Standings -> Instant
elapsed (Standings s) =
    s.elapsed


{-| How close two cars have to be for the standings to show them as a battle.
-}
closeIntervalThreshold : Duration
closeIntervalThreshold =
    1500


groupCarsByCloseIntervals : Standings -> List (List Entry)
groupCarsByCloseIntervals (Standings s) =
    let
        isCloseToNext current =
            Gap.isWithin closeIntervalThreshold current.intervalToAhead

        groupCars cars =
            case cars of
                [] ->
                    []

                first :: rest ->
                    let
                        ( group, remaining ) =
                            List.Extra.span isCloseToNext rest
                    in
                    (first :: group) :: groupCars remaining
    in
    SortedList.toList s.entries
        |> groupCars
        |> List.filter (\group -> List.length group >= 2)
