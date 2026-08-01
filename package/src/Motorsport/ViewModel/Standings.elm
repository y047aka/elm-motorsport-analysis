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
import Motorsport.BestTimes as BestTimes
import Motorsport.Circuit.LeMans as LeMans
import Motorsport.Class as Class
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance exposing (RatedTime, performanceLevel)
import Motorsport.Ordering as Ordering exposing (ByPosition)
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Sector as Sector
import Motorsport.Status as Status exposing (Status)
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


compute : BestTimes.Snapshot -> { elapsed : Instant } -> Race -> Standings
compute bestTimes clock race =
    let
        fastestLapTime =
            BestTimes.timeOf bestTimes.fastestLapTime

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
                                |> Maybe.andThen
                                    (\lap ->
                                        rateTime fastestLapTime
                                            { time = Just timing.currentLapElapsed
                                            , personalBest = Lap.recorded lap.best
                                            }
                                    )
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
                                |> Maybe.andThen
                                    (\lap ->
                                        rateTime fastestLapTime
                                            { time = Lap.recorded lap.time
                                            , personalBest = Lap.recorded lap.best
                                            }
                                    )
                        , bestLapRated =
                            car.lastLap
                                |> Maybe.andThen
                                    (\lap ->
                                        rateTime fastestLapTime
                                            { time = Lap.recorded lap.best
                                            , personalBest = Lap.recorded lap.best
                                            }
                                    )
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
                            rateTime fastestLapTime
                                { time = Lap.recorded lap.time, personalBest = Lap.recorded lap.best }
                        , bestLapRated =
                            rateTime fastestLapTime
                                { time = Lap.recorded lap.best, personalBest = Lap.recorded lap.best }
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


{-| A [`Car`](Motorsport-Race-Car) as it stands at one moment of the race,
rebuilt on every frame rather than stored.

Written as a [`Gap.Competitor`](Motorsport-Gap#Competitor) with the rest added
on, because that is the shape the ordering depends on: `Gap.at` and
`Ordering.runningOrder` reach for `laps` and `currentLap` directly, so those two
have to stay at the top level rather than nesting inside a `Car`.

-}
type alias CarState =
    Gap.Competitor
        { metadata : Car.Metadata
        , lastLap : Maybe Lap
        , status : Status
        , currentDriver : Maybe Driver
        }


{-| Read a car at a moment of the race. The status is looked up rather than
worked out here; see [`Race.statusAt`](Motorsport-Race#statusAt).
-}
carStateAt : { elapsed : Instant } -> Race -> Car -> CarState
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


extractSectorPerformance : BestTimes.Snapshot -> Lap -> SectorPerformance
extractSectorPerformance bestTimes lap =
    Sector.map2
        (\fastest sectorTime ->
            rateTime (BestTimes.timeOf fastest)
                { time = Lap.recorded sectorTime.time
                , personalBest = Lap.recorded sectorTime.personalBest
                }
        )
        bestTimes.fastestSectors
        lap.sectors


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


type alias TimingState =
    { currentLapElapsed : Duration
    , sector : Maybe Lap.SectorProgress
    , miniSector : Maybe Lap.MiniSectorProgress
    , gapToLeader : Gap
    , intervalToAhead : Gap
    }


init_timing : Instant -> { leader : Maybe CarState, rival : Maybe CarState } -> CarState -> TimingState
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
    { currentLapElapsed = Instant.since { from = lastLap.elapsed, to = raceClock.elapsed }
    , sector = currentSector
    , miniSector = currentMiniSector
    , gapToLeader = gapTo raceClock car rivals.leader
    , intervalToAhead = gapTo raceClock car rivals.rival
    }


{-| The gap from `car` to the car ahead of it, or none where there is no such car.
-}
gapTo : { elapsed : Instant } -> CarState -> Maybe CarState -> Gap
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
