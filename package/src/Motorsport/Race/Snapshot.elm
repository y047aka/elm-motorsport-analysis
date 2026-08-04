module Motorsport.Race.Snapshot exposing
    ( Snapshot, CarAt, CurrentLap, LastLap, CurrentSectorStates
    , at
    , toList, toClassList, get, inClass, leader, lapCount, elapsed
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

A `CarAt` is what the timing screen draws a line from, and it is readings only:
a view that wants the class's colour asks
[`Class.toColor`](Motorsport-Class#toColor) for it.

The records the times are rated against and the laps run so far are read at the
same clock, so they are taken here too rather than by each caller: see
[`bestTimes`](#bestTimes) and [`lapHistory`](#lapHistory).

Reading one car or one class out of the field is the snapshot's own business --
`get` and `inClass` below -- so that a view narrowing the field does not have to
scan `toList` for it.

@docs Snapshot, CarAt, CurrentLap, LastLap, CurrentSectorStates
@docs at
@docs toList, toClassList, get, inClass, leader, lapCount, elapsed
@docs bestTimes, lapHistory

-}

import Dict exposing (Dict)
import Motorsport.BestTimes as BestTimes
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap, MiniSectors)
import Motorsport.Lap.Performance as Performance exposing (MiniSectorPerformance, RatedTime, SectorPerformance)
import Motorsport.Ordering as Ordering exposing (ByPosition)
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Car as Car exposing (Car, CarNumber)
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

        -- The same cars again, to look one up by number. Built with the rest of
        -- the frame so that `get` costs a lookup rather than a scan of the
        -- field; two cars sharing a number leave only the leading one here,
        -- which is the one a caller asking by number wants.
        , carsByNumber : Dict CarNumber CarAt
        }


{-| One [`Car`](Motorsport-Race-Car) as it stands at one moment of the race.

Readings only -- no laps of any kind. The whole list runs to the end of the
race, and handing it out beside values that stop at the clock is how future data
gets read by accident; the laps up to this moment are
[`lapHistory`](#lapHistory)'s to give out, already cut. A lap the car has
already turned is here as what was read off it -- `lapsCompleted`, and
[`lastLap`](#LastLap) -- rather than as the lap itself.

What is read off the lap in progress and off the one just finished is grouped
under [`currentLap`](#CurrentLap) and [`lastLap`](#LastLap), so that the two
cannot be mistaken for one another at a call site; what stands apart from both
-- who the car is, where it stands, the gaps it holds -- stays at the top.

-}
type alias CarAt =
    { metadata : Car.Metadata
    , status : Status
    , currentDriver : Maybe Driver
    , position : Int
    , positionInClass : Int
    , lapsCompleted : Int
    , gapToLeader : Gap
    , intervalToAhead : Gap
    , currentLap : CurrentLap
    , lastLap : LastLap

    -- The quickest lap the car has turned by this moment, rated. Neither the
    -- lap it is on nor the one it just finished, so it belongs to neither
    -- group.
    , bestLapRated : Maybe RatedTime
    }


{-| The lap the car is on, as it reads at this moment.

`time` and `best` are the lap's own, as the source data has them; `elapsed` is
how long the car has been on it, counted from the last time it crossed the line
-- or from the race start, for a car still on its opening lap.

`progress`, `sector` and `miniSector` say how far around the car has got. All
three come off the clock and the lap's own times, so they say where the car is,
not how anything is drawn. Singular `miniSector` is one of those three -- which
mini-sector the car is in, and how far through it; plural `miniSectors` is the
lap's recorded mini-sector times, which is data rather than a position.

`sector`, `miniSector` and `sectorStates` are `Nothing` together, for a car with
no lap in progress: a car that is not on a lap is nowhere on the track.

`rated` and `sectorStates` are rated against the record the race held at this
moment; see [`Lap.Performance`](Motorsport-Lap-Performance).

-}
type alias CurrentLap =
    { time : Maybe Duration
    , best : Maybe Duration
    , miniSectors : Maybe MiniSectors
    , elapsed : Duration
    , progress : Float
    , sector : Maybe Lap.SectorProgress
    , miniSector : Maybe Lap.MiniSectorProgress
    , rated : Maybe RatedTime
    , sectorStates : Maybe CurrentSectorStates
    }


{-| The lap the car has just finished, as it was read off it.

The lap itself is not here -- see [`CarAt`](#CarAt) -- only what was read: the
time it took and how its sectors went, each rated against the record the race
held at this moment.

`miniSectors` is `Nothing` away from Le Mans, where the source data records no
mini-sectors to rate.

-}
type alias LastLap =
    { rated : Maybe RatedTime
    , sectors : Maybe SectorPerformance
    , miniSectors : Maybe MiniSectorPerformance
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

        cars =
            placeInField sampled
                |> List.map
                    (readCarAt
                        { raceElapsed = clock.elapsed
                        , records = records
                        , fastestLapTime = BestTimes.timeOf records.fastestLapTime
                        , leaderCar = List.head sampled
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
        , carsByNumber = indexByCarNumber cars
        , bestTimes = records
        , lapHistory = LapHistory.at clock race.cars
        }


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


{-| Index the field by car number.

Folded from the right so that the leading car wins a number two cars share:
`Dict.insert` keeps the last write, and folding backwards makes that the car
earliest in the running order.

-}
indexByCarNumber : List CarAt -> Dict CarNumber CarAt
indexByCarNumber =
    List.foldr (\car -> Dict.insert car.metadata.carNumber car) Dict.empty


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


{-| One car of the field by its number, where the race has such a car.
-}
get : CarNumber -> Snapshot -> Maybe CarAt
get carNumber (Snapshot s) =
    Dict.get carNumber s.carsByNumber


{-| The cars racing in one class, in running order.

The same list [`toClassList`](#toClassList) holds that class under, for a caller
that already knows which class it wants. A class no car races in is empty rather
than absent: there is nothing to draw either way.

-}
inClass : Class -> Snapshot -> List CarAt
inClass class (Snapshot s) =
    s.carsByClass
        |> List.filter (\( carClass, _ ) -> carClass == class)
        |> List.head
        |> Maybe.map Tuple.second
        |> Maybe.withDefault []


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


{-| The moment of the race this snapshot was taken at.
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

        -- A car on its opening lap has no lap behind it, and that lap began at
        -- the race start -- which is the instant `Lap.empty` carries. So the
        -- empty lap stands in for the missing one here rather than papering
        -- over it: both the elapsed time below and the mini-sector's own start
        -- come out right for a first lap.
        lastLap =
            Maybe.withDefault Lap.empty car.lastLap
    in
    { currentLapElapsed = Instant.since { from = lastLap.elapsed, to = raceClock.elapsed }
    , sector =
        -- Only a car with a lap in progress is anywhere on the lap. Reading a
        -- sector off `Lap.empty` would place every car without lap data at the
        -- start of the track, which is a position it does not hold.
        car.currentLap
            |> Maybe.map
                (\lap ->
                    let
                        sectorProgress =
                            Lap.progressAt raceClock lap
                    in
                    { sectorProgress | progress = min 1 sectorProgress.progress }
                )
    , miniSector =
        car.currentLap
            |> Maybe.andThen
                (\lap -> Lap.miniSectorProgressAt raceClock { current = lap, previous = lastLap })
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


{-| A sampled car with its place in the field: what it stands overall, what it
stands in its class, and which car it is running directly behind.
-}
type alias Placed =
    { car : SampledCar
    , position : Int
    , positionInClass : Int
    , ahead : Maybe SampledCar
    }


{-| Number the field off in one pass over the running order.

Class position is counted as the cars go past rather than looked up afterwards.
A lookup has to be keyed by car number, and two cars sharing one -- which the
source data occasionally has -- would collapse into a single entry, leaving the
other car to fall back on a position it does not hold. Counting cannot miss a
car that is in the list, so there is no fallback to get wrong.

The car ahead comes off the same pass, which is also the car each interval is
measured to; the first car has none, and reports no interval.

-}
placeInField : List SampledCar -> List Placed
placeInField carsInRunningOrder =
    carsInRunningOrder
        |> List.foldl
            (\car state ->
                let
                    classKey =
                        Class.toString car.metadata.class

                    positionInClass =
                        Dict.get classKey state.positionsInClass
                            |> Maybe.withDefault 0
                            |> (+) 1
                in
                { position = state.position + 1
                , positionsInClass = Dict.insert classKey positionInClass state.positionsInClass
                , ahead = Just car
                , placed =
                    { car = car
                    , position = state.position
                    , positionInClass = positionInClass
                    , ahead = state.ahead
                    }
                        :: state.placed
                }
            )
            { position = 1
            , positionsInClass = Dict.empty
            , ahead = Nothing
            , placed = []
            }
        |> .placed
        |> List.reverse


readCarAt :
    { raceElapsed : Instant
    , records : BestTimes.Snapshot
    , fastestLapTime : Maybe Duration
    , leaderCar : Maybe SampledCar
    }
    -> Placed
    -> CarAt
readCarAt frame placed =
    let
        car =
            placed.car

        timing =
            timingOf frame.raceElapsed
                { leader =
                    -- The leader is not behind itself; it has no gap to report.
                    if placed.position == 1 then
                        Nothing

                    else
                        frame.leaderCar
                , rival = placed.ahead
                }
                car
    in
    { metadata = car.metadata
    , status = car.status
    , currentDriver = car.currentDriver
    , position = placed.position
    , positionInClass = placed.positionInClass
    , lapsCompleted = car.lastLap |> Maybe.map .lap |> Maybe.withDefault 0
    , gapToLeader = timing.gapToLeader
    , intervalToAhead = timing.intervalToAhead
    , currentLap =
        { time = car.currentLap |> Maybe.andThen .time
        , best = car.currentLap |> Maybe.andThen .best
        , miniSectors = car.currentLap |> Maybe.andThen .miniSectors
        , elapsed = timing.currentLapElapsed
        , progress =
            car.currentLap
                |> Maybe.andThen .time
                |> Maybe.map (\lapTime -> min 1.0 (toFloat timing.currentLapElapsed / toFloat lapTime))
                |> Maybe.withDefault 0
        , sector = timing.sector
        , miniSector = timing.miniSector
        , rated =
            car.currentLap
                |> Maybe.andThen
                    (\lap ->
                        Performance.rateTime frame.fastestLapTime
                            { time = Just timing.currentLapElapsed
                            , personalBest = lap.best
                            }
                    )
        , sectorStates =
            car.currentLap
                |> Maybe.map
                    (Performance.ofSectors frame.records
                        >> currentSectorStates timing.sector
                    )
        }
    , lastLap =
        { rated =
            car.lastLap
                |> Maybe.andThen
                    (\lap ->
                        Performance.rateTime frame.fastestLapTime
                            { time = lap.time, personalBest = lap.best }
                    )
        , sectors =
            car.lastLap |> Maybe.map (Performance.ofSectors frame.records)
        , miniSectors =
            car.lastLap |> Maybe.andThen (Performance.ofMiniSectors frame.records)
        }
    , bestLapRated =
        car.lastLap
            |> Maybe.andThen
                (\lap ->
                    Performance.rateTime frame.fastestLapTime
                        { time = lap.best, personalBest = lap.best }
                )
    }
