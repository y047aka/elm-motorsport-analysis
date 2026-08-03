module Motorsport.Race.Snapshot exposing
    ( Snapshot, CarAt, CurrentSectorStates
    , at
    , toList, toClassList, leader, lapCount, elapsed
    , bestTimes, lapHistory
    )

{-| A [`Race`](Motorsport-Race) read at one moment of it.

The race itself never moves; a snapshot is what the cars are actually doing once
a clock is applied to it -- which lap each is on, who is ahead of whom, and how
far apart they are. All of it is settled by the race data and the clock alone, so
swapping the view layer out would not change a single number here.

Rebuilt on every frame rather than stored, and built once per frame so the
several views that need the same order and the same gaps do not each work them
out again. That sharing is the whole reason the type exists: without it the
sort, the gaps and the ratings would run once per view.

A `CarAt` is what the timing screen draws a line from. It carries no colours and
no geometry of its own -- a view that wants the class's colour asks
[`Class.toColor`](Motorsport-Class#toColor) for it.

The records the times are rated against and the laps run so far are read at the
same clock, so they are taken here too rather than by each caller: see
[`bestTimes`](#bestTimes) and [`lapHistory`](#lapHistory).

@docs Snapshot, CarAt, CurrentSectorStates
@docs at
@docs toList, toClassList, leader, lapCount, elapsed
@docs bestTimes, lapHistory

-}

import Dict exposing (Dict)
import List.Extra
import Motorsport.BestTimes as BestTimes
import Motorsport.Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap, MiniSectors)
import Motorsport.Lap.Performance as Performance exposing (MiniSectorPerformance, RatedTime, SectorPerformance)
import Motorsport.Ordering as Ordering exposing (ByPosition)
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Status exposing (Status)
import SortedList exposing (SortedList)


{-| Every car of the race as it stands at one moment, in running order.

Named as [`BestTimes.Snapshot`](Motorsport-BestTimes#Snapshot) is, and for the
same reason: a subject of the race held still, with the clock it was read at
baked in. That one is the records at a moment; this is the field at a moment.

-}
type Snapshot
    = Snapshot
        { elapsed : Instant
        , lapCount : Int
        , cars : SortedList ByPosition CarAt
        , bestTimes : BestTimes.Snapshot
        , lapHistory : LapHistory

        -- Plain lists here (already position-sorted by construction, see
        -- groupByClass): consumers of toClassList only ever render these cars,
        -- never re-sort them, so the phantom-typed SortedList guarantee isn't
        -- worth the extra unwrapping at each call site.
        , carsByClass : List ( Class, List CarAt )
        }


{-| One [`Car`](Motorsport-Race-Car) as it stands at one moment of the race.

Readings only -- no laps of any kind. The whole list runs to the end of the
race, and handing it out beside values that stop at the clock is how future data
gets read by accident; the laps up to this moment are
[`lapHistory`](#lapHistory)'s to give out, already cut. A lap the car has
already turned is here as what was read off it -- `lapsCompleted`,
`lastLapRated`, `lastLapSectors` -- rather than as the lap itself.

-}
type alias CarAt =
    { metadata : Car.Metadata
    , status : Status
    , currentDriver : Maybe Driver
    , position : Int
    , positionInClass : Int
    , lapsCompleted : Int
    , currentLapTime : Maybe Duration
    , currentLapBest : Maybe Duration
    , currentLapMiniSectors : Maybe MiniSectors
    , currentLapElapsed : Duration

    -- How far through the lap and through the sector the car is. Both are
    -- read off the clock and the lap's own times, so they say where the car
    -- is, not how anything is drawn.
    , currentLapProgress : Float
    , sector : Maybe Lap.SectorProgress
    , miniSector : Maybe Lap.MiniSectorProgress
    , gapToLeader : Gap
    , intervalToAhead : Gap

    -- Rated against the record the race held at this moment; see
    -- [`Lap.Performance`](Motorsport-Lap-Performance).
    , currentLapRated : Maybe RatedTime
    , currentLapSectorStates : Maybe CurrentSectorStates
    , lastLapRated : Maybe RatedTime
    , bestLapRated : Maybe RatedTime
    , lastLapSectors : Maybe SectorPerformance
    , lastLapMiniSectors : Maybe MiniSectorPerformance
    }


{-| Where the car stands in each sector of the lap it is on: how much of the
sector is behind it, and how the time reads where there is one.

`rated` is `Nothing` for a sector the source data has no time for, the same way
a mini-sector's is; there is nothing to colour it by.

-}
type alias CurrentSectorStates =
    BySector { progress : Float, rated : Maybe RatedTime }


{-| Read the whole race at a moment of it.

Every number is read at the same clock, the records included: a time is rated
against the record as it stood then, not as it ends up. Right after the data
loads the clock sits at the start, so nothing holds a record yet -- a page that
wants the race's final records asks
[`BestTimes.final`](Motorsport-BestTimes#final) for them instead.

-}
at : { elapsed : Instant } -> Race -> Snapshot
at clock race =
    let
        records =
            BestTimes.at clock race.bestTimeChanges

        -- A car carries only its laps, so what it is doing at this moment is
        -- read off the clock here. Who is ahead of whom follows from that, and
        -- every position below is read off the resulting order.
        sampled =
            race.cars
                |> List.map (sampleCar clock race)
                |> Ordering.runningOrder clock

        leaderCar =
            List.head sampled

        positionsInClass =
            positionsInClassByCarNumber sampled

        fastestLapTime =
            BestTimes.timeOf records.fastestLapTime

        cars =
            sampled
                |> List.indexedMap
                    (\index car ->
                        let
                            timing =
                                timingOf clock.elapsed
                                    { leader =
                                        -- The leader is not behind itself; it has no gap to report.
                                        if index == 0 then
                                            Nothing

                                        else
                                            leaderCar
                                    , rival = List.Extra.getAt (index - 1) sampled
                                    }
                                    car
                        in
                        { metadata = car.metadata
                        , status = car.status
                        , currentDriver = car.currentDriver
                        , position = index + 1
                        , positionInClass =
                            Dict.get car.metadata.carNumber positionsInClass
                                |> Maybe.withDefault 1
                        , lapsCompleted = (Maybe.withDefault Lap.empty car.lastLap).lap
                        , currentLapTime = car.currentLap |> Maybe.andThen .time
                        , currentLapBest = car.currentLap |> Maybe.andThen .best
                        , currentLapMiniSectors = car.currentLap |> Maybe.andThen .miniSectors
                        , currentLapElapsed = timing.currentLapElapsed
                        , currentLapProgress =
                            car.currentLap
                                |> Maybe.andThen .time
                                |> Maybe.map (\lapTime -> min 1.0 (toFloat timing.currentLapElapsed / toFloat lapTime))
                                |> Maybe.withDefault 0
                        , sector = timing.sector
                        , miniSector = timing.miniSector
                        , gapToLeader = timing.gapToLeader
                        , intervalToAhead = timing.intervalToAhead
                        , currentLapRated =
                            car.currentLap
                                |> Maybe.andThen
                                    (\lap ->
                                        Performance.rateTime fastestLapTime
                                            { time = Just timing.currentLapElapsed
                                            , personalBest = lap.best
                                            }
                                    )
                        , currentLapSectorStates =
                            car.currentLap
                                |> Maybe.map
                                    (Performance.ofSectors records
                                        >> currentSectorStates timing.sector
                                    )
                        , lastLapRated =
                            car.lastLap
                                |> Maybe.andThen
                                    (\lap ->
                                        Performance.rateTime fastestLapTime
                                            { time = lap.time, personalBest = lap.best }
                                    )
                        , bestLapRated =
                            car.lastLap
                                |> Maybe.andThen
                                    (\lap ->
                                        Performance.rateTime fastestLapTime
                                            { time = lap.best, personalBest = lap.best }
                                    )
                        , lastLapSectors =
                            car.lastLap |> Maybe.map (Performance.ofSectors records)
                        , lastLapMiniSectors =
                            car.lastLap |> Maybe.andThen (Performance.ofMiniSectors records)
                        }
                    )

        sortedCars =
            Ordering.byPosition cars
    in
    Snapshot
        { elapsed = clock.elapsed
        , lapCount = Race.lapCountAt clock race
        , cars = sortedCars
        , carsByClass = groupByClass sortedCars
        , bestTimes = records
        , lapHistory = LapHistory.at clock race.cars
        }


{-| Where each sector of the current lap stands: how far through it the car is,
laid over how the time it has set there reads.
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


groupByClass : SortedList ByPosition CarAt -> List ( Class, List CarAt )
groupByClass sortedCars =
    sortedCars
        |> SortedList.gatherEqualsBy (.metadata >> .class)
        |> List.map (\( first, rest ) -> ( first.metadata.class, first :: SortedList.toList rest ))


{-| The cars in running order, the leader first.
-}
toList : Snapshot -> List CarAt
toList (Snapshot s) =
    SortedList.toList s.cars


{-| The cars grouped by the class they race in, each group in running order.
-}
toClassList : Snapshot -> List ( Class, List CarAt )
toClassList (Snapshot s) =
    s.carsByClass


{-| The car leading the race, where there is one.
-}
leader : Snapshot -> Maybe CarAt
leader (Snapshot s) =
    SortedList.head s.cars


{-| How many laps the leader has completed at this moment.
-}
lapCount : Snapshot -> Int
lapCount (Snapshot s) =
    s.lapCount


{-| The moment of the race this snapshot was taken at; the clock passed to
[`at`](#at) is baked in.
-}
elapsed : Snapshot -> Instant
elapsed (Snapshot s) =
    s.elapsed


{-| The records the race held at this moment.
-}
bestTimes : Snapshot -> BestTimes.Snapshot
bestTimes (Snapshot s) =
    s.bestTimes


{-| Every lap each car had completed by this moment.
-}
lapHistory : Snapshot -> LapHistory
lapHistory (Snapshot s) =
    s.lapHistory



-- INTERNALS


{-| A car before the field has been put in order: everything that can be read
from the car alone, without knowing who else is out there.

A [`Gap.Competitor`](Motorsport-Gap#Competitor) with the rest added on, because
that is the shape the ordering depends on: `Gap.at` and `Ordering.runningOrder`
reach for `laps` and `currentLap` directly, so those two have to sit at the top
level here. The constraint stops at this type; what comes out the other side is
a `CarAt`, which carries neither.

The status is looked up rather than worked out here; see
[`Race.statusAt`](Motorsport-Race#statusAt).

-}
type alias SampledCar =
    Gap.Competitor
        { metadata : Car.Metadata
        , lastLap : Maybe Lap
        , status : Status
        , currentDriver : Maybe Driver
        }


sampleCar : { elapsed : Instant } -> Race -> Car -> SampledCar
sampleCar clock race car =
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


type alias Timing =
    { currentLapElapsed : Duration
    , sector : Maybe Lap.SectorProgress
    , miniSector : Maybe Lap.MiniSectorProgress
    , gapToLeader : Gap
    , intervalToAhead : Gap
    }


timingOf : Instant -> { leader : Maybe SampledCar, rival : Maybe SampledCar } -> SampledCar -> Timing
timingOf raceElapsed rivals car =
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
gapTo : { elapsed : Instant } -> SampledCar -> Maybe SampledCar -> Gap
gapTo raceClock car ahead =
    ahead
        |> Maybe.map (\aheadCar -> Gap.at raceClock { ahead = aheadCar, behind = car })
        |> Maybe.withDefault Gap.none


{-| Position within class, keyed by car number. Expects the cars already in
running order, so gathering by class preserves it.
-}
positionsInClassByCarNumber : List SampledCar -> Dict String Int
positionsInClassByCarNumber carsInRaceOrder =
    carsInRaceOrder
        |> List.Extra.gatherEqualsBy (.metadata >> .class)
        |> List.concatMap
            (\( firstCar, restCars ) ->
                (firstCar :: restCars)
                    |> List.indexedMap (\index car -> ( car.metadata.carNumber, index + 1 ))
            )
        |> Dict.fromList
