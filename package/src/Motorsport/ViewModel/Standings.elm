module Motorsport.ViewModel.Standings exposing
    ( Standings, Entry, ClassInfo
    , SectorProgress, MiniSectorProgress
    , SectorTimes, CurrentSectorStates
    , SectorPerformance, MiniSectorPerformance
    , compute, fromLaps, fromList
    , toList, toClassList, leader, lapCount, elapsed
    , classInfoOf
    , groupCarsByCloseIntervals
    )

{-|

@docs Standings, Entry, ClassInfo
@docs SectorProgress, MiniSectorProgress
@docs SectorTimes, CurrentSectorStates
@docs SectorPerformance, MiniSectorPerformance
@docs compute, fromLaps, fromList

@docs toList, toClassList, leader, lapCount, elapsed

@docs classInfoOf

@docs groupCarsByCloseIntervals

-}

import Dict exposing (Dict)
import List.Extra
import Motorsport.Car as Car exposing (Car, Status)
import Motorsport.Circuit.LeMans exposing (LeMans2025MiniSector)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap as Lap exposing (Lap, MiniSectors)
import Motorsport.Lap.Performance exposing (LeMans2025MiniSectorFastest, RatedTime, calculateMiniSectorFastest, findFastestBy, performanceLevel)
import Motorsport.Ordering as Ordering exposing (ByPosition)
import Motorsport.RunningOrder as RunningOrder exposing (RunningOrder)
import Motorsport.Sector as Sector exposing (BySector, Sector)
import SortedList exposing (SortedList)


type Standings
    = Standings
        { elapsed : Duration
        , lapCount : Int
        , entries : SortedList ByPosition Entry

        -- Plain lists here (already position-sorted by construction, see
        -- groupEntriesByClass): consumers of toClassList only ever render
        -- these entries, never re-sort them, so the phantom-typed SortedList
        -- guarantee isn't worth the extra unwrapping at each call site.
        , entriesByClass : List ( ClassInfo, List Entry )
        }


{-| Display info needed by class headers and badges.
The season-dependent color resolution is already done at compute time.
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


type alias SectorTimes =
    { sector_1 : Duration
    , sector_2 : Duration
    , sector_3 : Duration
    , s1_best : Duration
    , s2_best : Duration
    , s3_best : Duration
    }


type alias SectorPerformance =
    BySector RatedTime


type alias MiniSectorPerformance =
    { scl2 : Maybe RatedTime
    , z4 : Maybe RatedTime
    , ip1 : Maybe RatedTime
    , z12 : Maybe RatedTime
    , sclc : Maybe RatedTime
    , a7_1 : Maybe RatedTime
    , ip2 : Maybe RatedTime
    , a8_1 : Maybe RatedTime
    , sclb : Maybe RatedTime
    , porin : Maybe RatedTime
    , porout : Maybe RatedTime
    , pitref : Maybe RatedTime
    , scl1 : Maybe RatedTime
    , fordout : Maybe RatedTime
    , fl : Maybe RatedTime
    }


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
    , currentLapSectors : Maybe SectorTimes
    , currentLapSectorStates : Maybe CurrentSectorStates
    , currentLapMiniSectors : Maybe MiniSectors
    , currentLapElapsed : Duration
    , currentLapRated : Maybe RatedTime
    , sector : Maybe SectorProgress
    , miniSector : Maybe MiniSectorProgress
    , gapToLeader : Gap
    , intervalToAhead : Gap
    , currentLapProgress : Float
    , lastLapRated : Maybe RatedTime
    , bestLapRated : Maybe RatedTime
    , lastLapSectors : Maybe SectorPerformance
    , lastLapMiniSectors : Maybe MiniSectorPerformance
    , currentDriver : Maybe Driver
    }


type alias SectorProgress =
    { sector : Sector
    , progress : Float
    }


{-| Per-sector "progress + performance rating" for the current lap.
Rated at compute time so donut displays can render without being supplied BestTimes separately.
-}
type alias CurrentSectorStates =
    BySector { progress : Float, rated : RatedTime }


type alias MiniSectorProgress =
    { miniSector : LeMans2025MiniSector
    , progress : Float
    }


compute :
    { season : Int }
    ->
        { a
            | fastestLapTime : Duration
            , fastestSector_1 : Duration
            , fastestSector_2 : Duration
            , fastestSector_3 : Duration
            , fastestMiniSectors : LeMans2025MiniSectorFastest
        }
    -> { elapsed : Duration, lapCount : Int, cars : RunningOrder }
    -> Standings
compute { season } bestTimes config =
    let
        carsList =
            RunningOrder.toList config.cars

        leaderCar =
            RunningOrder.leader config.cars

        positionsInClass =
            positionsInClassByCarNumber config.cars

        entries =
            carsList
                |> List.indexedMap
                    (\index car ->
                        let
                            metadata =
                                car.metadata

                            positionInClass =
                                Dict.get car.metadata.carNumber positionsInClass
                                    |> Maybe.withDefault 1

                            lastLap =
                                Maybe.withDefault Lap.empty car.lastLap

                            currentLap =
                                car.currentLap

                            timing =
                                init_timing config.elapsed
                                    { leader = Just leaderCar
                                    , rival = List.Extra.getAt (index - 1) carsList
                                    }
                                    car
                        in
                        { position = index + 1
                        , positionInClass = positionInClass
                        , status = car.status
                        , metadata = metadata
                        , classColor = (Class.toHexColor season metadata.class).value
                        , lapsCompleted = lastLap.lap
                        , currentLapTime = currentLap |> Maybe.map .time
                        , currentLapBest = currentLap |> Maybe.map .best
                        , currentLapSectors = currentLap |> Maybe.map extractSectorTimes
                        , currentLapSectorStates = currentLap |> Maybe.map (extractCurrentSectorStates bestTimes timing.sector)
                        , currentLapMiniSectors = currentLap |> Maybe.andThen .miniSectors
                        , currentLapElapsed = timing.currentLapElapsed
                        , currentLapRated =
                            currentLap
                                |> Maybe.map (\lap -> rateTime bestTimes.fastestLapTime { time = timing.currentLapElapsed, personalBest = lap.best })
                        , sector = timing.sector
                        , miniSector = timing.miniSector
                        , gapToLeader = timing.gapToLeader
                        , intervalToAhead = timing.intervalToAhead
                        , currentLapProgress =
                            currentLap
                                |> Maybe.map (\lap -> min 1.0 (toFloat timing.currentLapElapsed / toFloat lap.time))
                                |> Maybe.withDefault 0
                        , lastLapRated =
                            car.lastLap
                                |> Maybe.map (\lap -> rateTime bestTimes.fastestLapTime { time = lap.time, personalBest = lap.best })
                        , bestLapRated =
                            car.lastLap
                                |> Maybe.map (\lap -> rateTime bestTimes.fastestLapTime { time = lap.best, personalBest = lap.best })
                        , lastLapSectors = car.lastLap |> Maybe.map (extractSectorPerformance bestTimes)
                        , lastLapMiniSectors = car.lastLap |> Maybe.andThen (extractMiniSectorPerformance bestTimes)
                        , currentDriver = car.currentDriver
                        }
                    )

        sortedEntries =
            Ordering.byPosition entries
    in
    Standings
        { elapsed = config.elapsed
        , lapCount = config.lapCount
        , entries = sortedEntries
        , entriesByClass = groupEntriesByClass sortedEntries
        }


{-| For debugging: builds a Standings from a single car's lap list.

Treats each lap as one Entry, setting `metadata.carNumber` to the lap-number string.

-}
fromLaps : { season : Int } -> Car.Metadata -> List Lap -> Standings
fromLaps { season } baseMetadata laps =
    let
        bestTimes =
            { fastestLapTime = laps |> List.map .time |> List.filter ((/=) 0) |> List.minimum |> Maybe.withDefault 0
            , fastestSector_1 = [ laps ] |> findFastestBy .sector_1 |> Maybe.withDefault 0
            , fastestSector_2 = [ laps ] |> findFastestBy .sector_2 |> Maybe.withDefault 0
            , fastestSector_3 = [ laps ] |> findFastestBy .sector_3 |> Maybe.withDefault 0
            , fastestMiniSectors = calculateMiniSectorFastest [ laps ]
            }

        entries =
            laps
                |> List.indexedMap
                    (\index lap ->
                        { position = index + 1
                        , positionInClass = index + 1
                        , status = Car.Racing
                        , metadata = { baseMetadata | carNumber = String.fromInt lap.lap }
                        , classColor = (Class.toHexColor season baseMetadata.class).value
                        , lapsCompleted = lap.lap
                        , currentLapTime = Just lap.time
                        , currentLapBest = Just lap.best
                        , currentLapSectors = Just (extractSectorTimes lap)
                        , currentLapSectorStates = Just (extractCurrentSectorStates bestTimes Nothing lap)
                        , currentLapMiniSectors = lap.miniSectors
                        , currentLapElapsed = 0
                        , currentLapRated = Nothing
                        , sector = Nothing
                        , miniSector = Nothing
                        , gapToLeader = Gap.None
                        , intervalToAhead = Gap.None
                        , currentLapProgress = 0
                        , lastLapRated =
                            Just (rateTime bestTimes.fastestLapTime { time = lap.time, personalBest = lap.best })
                        , bestLapRated =
                            Just (rateTime bestTimes.fastestLapTime { time = lap.best, personalBest = lap.best })
                        , lastLapSectors = Just (extractSectorPerformance bestTimes lap)
                        , lastLapMiniSectors = extractMiniSectorPerformance bestTimes lap
                        , currentDriver = Just lap.driver
                        }
                    )

        sortedEntries =
            Ordering.byPosition entries
    in
    Standings
        { elapsed = 0
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
        { elapsed = 0
        , lapCount = entries |> List.map .lapsCompleted |> List.maximum |> Maybe.withDefault 0
        , entries = sortedEntries
        , entriesByClass = groupEntriesByClass sortedEntries
        }


groupEntriesByClass : SortedList ByPosition Entry -> List ( ClassInfo, List Entry )
groupEntriesByClass sortedEntries =
    sortedEntries
        |> SortedList.gatherEqualsBy (.metadata >> .class)
        |> List.map (\( first, rest ) -> ( classInfoOf first, first :: SortedList.toList rest ))


{-| Extracts a class's display info from an entry.
-}
classInfoOf : Entry -> ClassInfo
classInfoOf entry =
    { class = entry.metadata.class
    , name = Class.toString entry.metadata.class
    , color = entry.classColor
    }


rateTime : Duration -> { time : Duration, personalBest : Duration } -> RatedTime
rateTime fastest { time, personalBest } =
    { time = time
    , performance = performanceLevel { time = time, personalBest = personalBest, fastest = fastest }
    }


extractSectorTimes : Lap -> SectorTimes
extractSectorTimes lap =
    { sector_1 = lap.sector_1
    , sector_2 = lap.sector_2
    , sector_3 = lap.sector_3
    , s1_best = lap.s1_best
    , s2_best = lap.s2_best
    , s3_best = lap.s3_best
    }


extractCurrentSectorStates :
    { a | fastestSector_1 : Duration, fastestSector_2 : Duration, fastestSector_3 : Duration }
    -> Maybe SectorProgress
    -> Lap
    -> CurrentSectorStates
extractCurrentSectorStates bestTimes sectorProgress lap =
    let
        -- Sectors the car has already driven through count as complete, the one
        -- it is in reports its own progress, and the ones ahead are untouched.
        -- With no sector in progress the lap is over, so all three are complete.
        progressOf sector =
            case sectorProgress of
                Just current ->
                    case Sector.compare sector current.sector of
                        LT ->
                            100

                        EQ ->
                            current.progress

                        GT ->
                            0

                Nothing ->
                    100
    in
    Sector.map2 (\progress rated -> { progress = progress, rated = rated })
        (Sector.initialize progressOf)
        (extractSectorPerformance bestTimes lap)


extractSectorPerformance :
    { a | fastestSector_1 : Duration, fastestSector_2 : Duration, fastestSector_3 : Duration }
    -> Lap
    -> SectorPerformance
extractSectorPerformance bestTimes lap =
    Sector.map2 rateTime (fastestBySector bestTimes) (timesBySector lap)


{-| The two adapters below are where the flat `sector_1` / `s1_best` /
`fastestSector_1` fields of the source records turn into per-sector values.
Keeping them here means the flattening is written once rather than at each site
that needs to look a sector up.
-}
fastestBySector :
    { a | fastestSector_1 : Duration, fastestSector_2 : Duration, fastestSector_3 : Duration }
    -> BySector Duration
fastestBySector bestTimes =
    { s1 = bestTimes.fastestSector_1
    , s2 = bestTimes.fastestSector_2
    , s3 = bestTimes.fastestSector_3
    }


timesBySector : Lap -> BySector { time : Duration, personalBest : Duration }
timesBySector lap =
    { s1 = { time = lap.sector_1, personalBest = lap.s1_best }
    , s2 = { time = lap.sector_2, personalBest = lap.s2_best }
    , s3 = { time = lap.sector_3, personalBest = lap.s3_best }
    }


extractMiniSectorPerformance :
    { a | fastestMiniSectors : LeMans2025MiniSectorFastest }
    -> Lap
    -> Maybe MiniSectorPerformance
extractMiniSectorPerformance bestTimes lap =
    lap.miniSectors
        |> Maybe.map
            (\ms ->
                let
                    rateMiniSector msd fastestTime =
                        Maybe.map2
                            (\t b -> rateTime fastestTime { time = t, personalBest = b })
                            msd.time
                            msd.best
                in
                { scl2 = rateMiniSector ms.scl2 bestTimes.fastestMiniSectors.scl2
                , z4 = rateMiniSector ms.z4 bestTimes.fastestMiniSectors.z4
                , ip1 = rateMiniSector ms.ip1 bestTimes.fastestMiniSectors.ip1
                , z12 = rateMiniSector ms.z12 bestTimes.fastestMiniSectors.z12
                , sclc = rateMiniSector ms.sclc bestTimes.fastestMiniSectors.sclc
                , a7_1 = rateMiniSector ms.a7_1 bestTimes.fastestMiniSectors.a7_1
                , ip2 = rateMiniSector ms.ip2 bestTimes.fastestMiniSectors.ip2
                , a8_1 = rateMiniSector ms.a8_1 bestTimes.fastestMiniSectors.a8_1
                , sclb = rateMiniSector ms.sclb bestTimes.fastestMiniSectors.sclb
                , porin = rateMiniSector ms.porin bestTimes.fastestMiniSectors.porin
                , porout = rateMiniSector ms.porout bestTimes.fastestMiniSectors.porout
                , pitref = rateMiniSector ms.pitref bestTimes.fastestMiniSectors.pitref
                , scl1 = rateMiniSector ms.scl1 bestTimes.fastestMiniSectors.scl1
                , fordout = rateMiniSector ms.fordout bestTimes.fastestMiniSectors.fordout
                , fl = rateMiniSector ms.fl bestTimes.fastestMiniSectors.fl
                }
            )


type alias TimingState =
    { currentLapElapsed : Duration
    , sector : Maybe SectorProgress
    , miniSector : Maybe MiniSectorProgress
    , gapToLeader : Gap
    , intervalToAhead : Gap
    }


init_timing : Duration -> { leader : Maybe Car, rival : Maybe Car } -> Car -> TimingState
init_timing raceElapsed rivals car =
    let
        raceClock =
            { elapsed = raceElapsed }

        currentLap =
            Maybe.withDefault Lap.empty car.currentLap

        lastLap =
            Maybe.withDefault Lap.empty car.lastLap

        currentSector =
            let
                ( sector, segment ) =
                    Lap.currentSegment raceClock currentLap
            in
            Just
                { sector = sector
                , progress =
                    min 100 ((toFloat (raceClock.elapsed - segment.start) / toFloat segment.time) * 100)
                }

        currentMiniSector =
            Lap.miniSectorProgressAt raceClock ( currentLap, lastLap )
                |> Maybe.map (\( ms, p ) -> { miniSector = ms, progress = p })
    in
    { currentLapElapsed = raceClock.elapsed - lastLap.elapsed
    , sector = currentSector
    , miniSector = currentMiniSector
    , gapToLeader =
        Maybe.map2 (Gap.at raceElapsed) rivals.leader (Just car)
            |> Maybe.withDefault Gap.None
    , intervalToAhead =
        Maybe.map2 (Gap.at raceElapsed) rivals.rival (Just car)
            |> Maybe.withDefault Gap.None
    }


positionsInClassByCarNumber : RunningOrder -> Dict String Int
positionsInClassByCarNumber raceOrder =
    raceOrder
        |> RunningOrder.toList
        |> List.Extra.gatherEqualsBy (.metadata >> .class)
        |> List.concatMap
            (\( firstCar, restCars ) ->
                (firstCar :: restCars)
                    |> List.indexedMap (\index car -> ( car.metadata.carNumber, index + 1 ))
            )
        |> Dict.fromList


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


{-| The race elapsed time this Standings represents; the elapsed passed to compute is baked in.
-}
elapsed : Standings -> Duration
elapsed (Standings s) =
    s.elapsed


groupCarsByCloseIntervals : Standings -> List (List Entry)
groupCarsByCloseIntervals (Standings s) =
    let
        isCloseToNext current =
            case current.intervalToAhead of
                Gap.Seconds duration ->
                    duration <= 1500

                _ ->
                    False

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
