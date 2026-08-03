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
import Motorsport.Circuit.LeMans as LeMans
import Motorsport.Class as Class
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance exposing (RatedTime, performanceLevel)
import Motorsport.Ordering as Ordering exposing (ByPosition)
import Motorsport.Race exposing (Race)
import Motorsport.Race.Car as Car
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt)
import Motorsport.Sector as Sector
import Motorsport.Status as Status
import Motorsport.ViewModel.Entry as Entry exposing (ClassInfo, CurrentSectorStates, Entry, MiniSectorPerformance, SectorPerformance)
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

The first half is [`Race.Snapshot`](Motorsport-Race-Snapshot)'s: sampling the
race, ordering the field, measuring the gaps. What is left here is the rendering
-- rating times against the record, and working out the progress a donut or a
track marker draws.

-}
compute : BestTimes.Snapshot -> { elapsed : Instant } -> Race -> Standings
compute bestTimes clock race =
    let
        snapshot =
            Snapshot.at clock race

        entries =
            Snapshot.toList snapshot
                |> List.map (entryOf bestTimes)

        sortedEntries =
            Ordering.byPosition entries
    in
    Standings
        { elapsed = Snapshot.elapsed snapshot
        , lapCount = Snapshot.lapCount snapshot
        , entries = sortedEntries
        , entriesByClass = groupEntriesByClass sortedEntries
        }


entryOf : BestTimes.Snapshot -> CarAt -> Entry
entryOf bestTimes car =
    let
        fastestLapTime =
            BestTimes.timeOf bestTimes.fastestLapTime

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
    , currentLapSectorStates = currentLap |> Maybe.map (extractCurrentSectorStates bestTimes car.sector)
    , currentLapMiniSectors = currentLap |> Maybe.andThen .miniSectors
    , currentLapElapsed = car.currentLapElapsed
    , currentLapRated =
        currentLap
            |> Maybe.andThen
                (\lap ->
                    rateTime fastestLapTime
                        { time = Just car.currentLapElapsed
                        , personalBest = lap.best
                        }
                )
    , sector = car.sector
    , miniSector = car.miniSector
    , gapToLeader = car.gapToLeader
    , intervalToAhead = car.intervalToAhead
    , currentLapProgress =
        currentLap
            |> Maybe.andThen .time
            |> Maybe.map (\lapTime -> min 1.0 (toFloat car.currentLapElapsed / toFloat lapTime))
            |> Maybe.withDefault 0
    , lastLapRated =
        car.lastLap
            |> Maybe.andThen
                (\lap ->
                    rateTime fastestLapTime
                        { time = lap.time, personalBest = lap.best }
                )
    , bestLapRated =
        car.lastLap
            |> Maybe.andThen
                (\lap ->
                    rateTime fastestLapTime
                        { time = lap.best, personalBest = lap.best }
                )
    , lastLapSectors = car.lastLap |> Maybe.map (extractSectorPerformance bestTimes)
    , lastLapMiniSectors = car.lastLap |> Maybe.andThen (extractMiniSectorPerformance bestTimes)
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
                        , currentLapSectorStates = Just (extractCurrentSectorStates bestTimes Nothing lap)
                        , currentLapMiniSectors = lap.miniSectors
                        , currentLapElapsed = 0
                        , currentLapRated = Nothing
                        , sector = Nothing
                        , miniSector = Nothing
                        , gapToLeader = Gap.none
                        , intervalToAhead = Gap.none
                        , currentLapProgress = 0
                        , lastLapRated =
                            rateTime fastestLapTime { time = lap.time, personalBest = lap.best }
                        , bestLapRated =
                            rateTime fastestLapTime { time = lap.best, personalBest = lap.best }
                        , lastLapSectors = Just (extractSectorPerformance bestTimes lap)
                        , lastLapMiniSectors = extractMiniSectorPerformance bestTimes lap
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


{-| Rate a time against the race's record and the car's own, where there is a
time to rate. A time the source data did not record produces no rating rather
than an uncoloured one, so a caller renders the same "-" it renders for a car
with no lap at all.
-}
rateTime : Maybe Duration -> { time : Maybe Duration, personalBest : Maybe Duration } -> Maybe RatedTime
rateTime fastest { time, personalBest } =
    time
        |> Maybe.map
            (\recordedTime ->
                { time = recordedTime
                , performance =
                    performanceLevel
                        { time = recordedTime, personalBest = personalBest, fastest = fastest }
                }
            )


extractCurrentSectorStates :
    BestTimes.Snapshot
    -> Maybe Lap.SectorProgress
    -> Lap
    -> CurrentSectorStates
extractCurrentSectorStates bestTimes sectorProgress lap =
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
    Sector.map2 (\progress rated -> { progress = progress, rated = rated })
        (Sector.initialize progressOf)
        (extractSectorPerformance bestTimes lap)


{-| A `SectorTime` is already the shape `rateTime` reads: a time that may not
have been recorded, and the driver's best to rate it against.
-}
extractSectorPerformance : BestTimes.Snapshot -> Lap -> SectorPerformance
extractSectorPerformance bestTimes lap =
    Sector.map2 (BestTimes.timeOf >> rateTime) bestTimes.fastestSectors lap.sectors


extractMiniSectorPerformance :
    BestTimes.Snapshot
    -> Lap
    -> Maybe MiniSectorPerformance
extractMiniSectorPerformance bestTimes lap =
    let
        rate miniSector fastest =
            rateTime (BestTimes.timeOf fastest)
                { time = miniSector.time, personalBest = miniSector.best }
    in
    lap.miniSectors
        |> Maybe.map (\ms -> LeMans.map2 rate ms bestTimes.fastestMiniSectors)


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
