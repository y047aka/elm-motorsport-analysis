module Motorsport.ViewModel.Standings exposing
    ( Standings
    , compute, fromLaps, fromList
    , toList, toClassList, leader, lapCount, elapsed
    , groupCarsByCloseIntervals
    )

{-| The whole timing screen at one moment of the race.

What a single line of it looks like is [`Entry`](Motorsport-ViewModel-Entry);
this module is how one gets built and read back.

@docs Standings
@docs compute, fromLaps, fromList

@docs toList, toClassList, leader, lapCount, elapsed

@docs groupCarsByCloseIntervals

-}

import Dict exposing (Dict)
import List.Extra
import Motorsport.Circuit.LeMans as LeMans exposing (ByMiniSector)
import Motorsport.Class as Class
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance exposing (RatedTime, calculateMiniSectorFastest, findFastestBy, performanceLevel)
import Motorsport.Ordering as Ordering exposing (ByPosition)
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Status as Status exposing (Status)
import Motorsport.ViewModel.Entry as Entry exposing (ClassInfo, CurrentSectorStates, Entry, MiniSectorPerformance, SectorPerformance)
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


compute :
    { a
        | fastestLapTime : Duration
        , fastestSectors : BySector Duration
        , fastestMiniSectors : ByMiniSector Duration
    }
    -> { elapsed : Duration }
    -> Race
    -> Standings
compute bestTimes clock race =
    let
        -- The entry list carries only the laps, so what each car is doing at
        -- this moment is read off the clock here. Who is ahead of whom follows
        -- from that, and every position below is read off the resulting order.
        carsList =
            race.cars
                |> List.map (carStateAt clock race)
                |> Ordering.runningOrder clock

        leaderCar =
            List.head carsList

        positionsInClass =
            positionsInClassByCarNumber carsList

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
                                init_timing clock.elapsed
                                    { leader =
                                        -- The leader is not behind itself; it has no gap to report.
                                        if index == 0 then
                                            Nothing

                                        else
                                            leaderCar
                                    , rival = List.Extra.getAt (index - 1) carsList
                                    }
                                    car
                        in
                        { position = index + 1
                        , positionInClass = positionInClass
                        , status = car.status
                        , metadata = metadata
                        , classColor = (Class.toColor metadata.class).value
                        , lapsCompleted = lastLap.lap
                        , currentLapTime = currentLap |> Maybe.map .time
                        , currentLapBest = currentLap |> Maybe.map .best
                        , currentLapSectors = currentLap |> Maybe.map .sectors
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
        { elapsed = clock.elapsed
        , lapCount = Race.lapCountAt clock race
        , entries = sortedEntries
        , entriesByClass = groupEntriesByClass sortedEntries
        }


{-| For debugging: builds a Standings from a single car's lap list.

Treats each lap as one Entry, setting `metadata.carNumber` to the lap-number string.

-}
fromLaps : Car.Metadata -> List Lap -> Standings
fromLaps baseMetadata laps =
    let
        bestTimes =
            { fastestLapTime = laps |> List.map .time |> List.filter ((/=) 0) |> List.minimum |> Maybe.withDefault 0
            , fastestSectors =
                Sector.initialize
                    (\sector ->
                        [ laps ]
                            |> findFastestBy (.sectors >> Sector.get sector >> .time)
                            |> Maybe.withDefault 0
                    )
            , fastestMiniSectors = calculateMiniSectorFastest [ laps ]
            }

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
                        , currentLapTime = Just lap.time
                        , currentLapBest = Just lap.best
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


{-| A car as it stands at one moment of the race.

Written as a [`Gap.Competitor`](Motorsport-Gap#Competitor) with the rest added
on, because that is the shape the ordering depends on: `Gap.at` and
`Ordering.runningOrder` reach for `laps` and `currentLap` directly, so those two
have to stay at the top level rather than nesting inside a `Car`.

Nothing is stored between frames. `carStateAt` rebuilds it from a
[`Car`](Motorsport-Race-Car) and an elapsed time, so the same elapsed always
gives the same state, however the clock got there.

-}
type alias CarState =
    Gap.Competitor
        { metadata : Car.Metadata
        , lastLap : Maybe Lap
        , status : Status
        , currentDriver : Maybe Driver
        }


{-| Read a car at a moment of the race.

The status comes from the race's precomputed change points rather than being
worked out here; see
[`Race.statusAt`](Motorsport-Race#statusAt).

-}
carStateAt : { elapsed : Duration } -> Race -> Car -> CarState
carStateAt clock race car =
    let
        currentLap =
            Lap.findCurrentLap clock car.laps
    in
    { metadata = car.metadata
    , laps = car.laps
    , currentLap = currentLap
    , lastLap = Lap.findLastLapAt clock car.laps
    , status = Race.statusAt clock car.metadata.carNumber race
    , currentDriver = Maybe.map .driver currentLap
    }


groupEntriesByClass : SortedList ByPosition Entry -> List ( ClassInfo, List Entry )
groupEntriesByClass sortedEntries =
    sortedEntries
        |> SortedList.gatherEqualsBy (.metadata >> .class)
        |> List.map (\( first, rest ) -> ( Entry.classInfoOf first, first :: SortedList.toList rest ))


rateTime : Duration -> { time : Duration, personalBest : Duration } -> RatedTime
rateTime fastest { time, personalBest } =
    { time = time
    , performance = performanceLevel { time = time, personalBest = personalBest, fastest = fastest }
    }


extractCurrentSectorStates :
    { a | fastestSectors : BySector Duration }
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


extractSectorPerformance :
    { a | fastestSectors : BySector Duration }
    -> Lap
    -> SectorPerformance
extractSectorPerformance bestTimes lap =
    Sector.map2 rateTime bestTimes.fastestSectors lap.sectors


extractMiniSectorPerformance :
    { a | fastestMiniSectors : ByMiniSector Duration }
    -> Lap
    -> Maybe MiniSectorPerformance
extractMiniSectorPerformance bestTimes lap =
    let
        rate recorded fastestTime =
            Maybe.map2
                (\time personalBest -> rateTime fastestTime { time = time, personalBest = personalBest })
                recorded.time
                recorded.best
    in
    lap.miniSectors
        |> Maybe.map (\ms -> LeMans.map2 rate ms bestTimes.fastestMiniSectors)


type alias TimingState =
    { currentLapElapsed : Duration
    , sector : Maybe Lap.SectorProgress
    , miniSector : Maybe Lap.MiniSectorProgress
    , gapToLeader : Gap
    , intervalToAhead : Gap
    }


init_timing : Duration -> { leader : Maybe CarState, rival : Maybe CarState } -> CarState -> TimingState
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
                sectorProgress =
                    Lap.progressAt raceClock currentLap
            in
            Just { sectorProgress | progress = min 1 sectorProgress.progress }

        currentMiniSector =
            Lap.miniSectorProgressAt raceClock { current = currentLap, previous = lastLap }
    in
    { currentLapElapsed = raceClock.elapsed - lastLap.elapsed
    , sector = currentSector
    , miniSector = currentMiniSector
    , gapToLeader = gapTo raceClock car rivals.leader
    , intervalToAhead = gapTo raceClock car rivals.rival
    }


{-| The gap from `car` to the car ahead of it, or none where there is no such car.
-}
gapTo : { elapsed : Duration } -> CarState -> Maybe CarState -> Gap
gapTo raceClock car ahead =
    ahead
        |> Maybe.map (\aheadCar -> Gap.at raceClock { ahead = aheadCar, behind = car })
        |> Maybe.withDefault Gap.none


{-| Position within class, keyed by car number. Expects the cars already in
running order, so gathering by class preserves it.
-}
positionsInClassByCarNumber : List CarState -> Dict String Int
positionsInClassByCarNumber carsInRaceOrder =
    carsInRaceOrder
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
