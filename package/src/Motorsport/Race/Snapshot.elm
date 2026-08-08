module Motorsport.Race.Snapshot exposing
    ( Snapshot, CarAt, Standing, CurrentLap, LastLap(..)
    , CurrentSectorStates, CurrentMiniSectorStates, MiniSectorReading(..)
    , at
    , toList, toClassList, get, inClass, leader, lapCount, elapsed
    , bestTimes, lapHistory
    )

{-| A [`Race`](Motorsport-Race) read at one moment of it.

The race itself never moves; a snapshot is what the cars are doing once a clock
is applied to it. Rebuilt on every frame rather than stored, and built once per
frame so that the several views needing the same order and the same gaps do not
each work them out again -- that sharing is the whole reason the type exists.

@docs Snapshot, CarAt, Standing, CurrentLap, LastLap
@docs CurrentSectorStates, CurrentMiniSectorStates, MiniSectorReading
@docs at
@docs toList, toClassList, get, inClass, leader, lapCount, elapsed
@docs bestTimes, lapHistory

-}

import Dict
import Motorsport.BestTimes as BestTimes
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (MiniSectorPerformance, PerformanceLevel, RatedTime, SectorPerformance, SegmentState)
import Motorsport.Ordering as Ordering exposing (ByPosition)
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Car as Car exposing (Car, CarNumber)
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Status exposing (Status)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (ByMiniSector)
import Motorsport.Wec.Class as Class exposing (Class)
import SortedList exposing (SortedList)


{-| Every car of the race as it stands at one moment, in running order.
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

Readings only, and no laps: the laps up to this moment are
[`lapHistory`](#lapHistory)'s to give out, already cut.

Every rating here is measured against the records as they stood at this moment,
not as the race leaves them -- the race's, held by [`bestTimes`](#bestTimes),
and the car's own, which is `bestLap`. See
[`Lap.Performance`](Motorsport-Lap-Performance).

-}
type alias CarAt =
    { metadata : Car.Metadata
    , status : Status
    , currentDriver : Driver
    , standing : Standing
    , currentLap : CurrentLap
    , lastLap : LastLap
    , bestLap : Maybe RatedTime
    }


{-| Where the car stands in the race at this moment: the five a classification
line is made of, in the order one prints them.

`lapsCompleted` counts laps the car has finished, so a car on its opening lap
has none. Both gaps are [`Gap.none`](Motorsport-Gap#none) for the leading car
and only for it.

-}
type alias Standing =
    { position : Int
    , positionInClass : Int
    , lapsCompleted : Int
    , gapToLeader : Gap
    , intervalToAhead : Gap
    }


{-| The lap the car is on, as it reads at this moment.

Every car of a [`Snapshot`](#Snapshot) has one -- a car that has turned no lap
is not in the field, and a lap stays the car's current one until the next
begins, so a car that has retired or taken the flag keeps the last it ran.

`elapsed` counts from the last time the car crossed the line, or from the race
start for a car on its opening lap.

-}
type alias CurrentLap =
    { elapsed : Duration
    , progress : Float
    , performance : PerformanceLevel
    , sector : Lap.SectorProgress
    , sectorStates : CurrentSectorStates
    , miniSectors : MiniSectorReading
    }


{-| Where the car is on its lap at the mini-sector grain, on a circuit timed to
one. `NotRecorded` away from Le Mans.

`current` is `Nothing` wherever [`Lap.miniSegments`](Motorsport-Lap#miniSegments)
could not place the car: past the last mini-sector, and inside one the source
data left without a running total. So it can fall mid-lap, with mini-sectors
still ahead of the car.

-}
type MiniSectorReading
    = NotRecorded
    | Recorded
        { states : CurrentMiniSectorStates
        , current : Maybe Lap.MiniSectorProgress
        }


{-| The lap the car has just finished, as it was read off it.

`rated` is `Nothing` for a lap the source data has no time for. `miniSectors` is
`Nothing` away from Le Mans, which records none.

-}
type LastLap
    = NoLapYet
    | Completed
        { rated : Maybe RatedTime
        , sectors : SectorPerformance
        , miniSectors : Maybe MiniSectorPerformance
        }


{-| Where the car stands in each sector of the lap it is on. See
[`SegmentState`](Motorsport-Lap-Performance#SegmentState).
-}
type alias CurrentSectorStates =
    BySector SegmentState


{-| The same reading at the finer grain.
-}
type alias CurrentMiniSectorStates =
    ByMiniSector SegmentState


{-| Read the whole race at a moment of it.

Every number is read at the same clock, the records included: a time is rated
against the record as it stood then, not as it ends up. Right after the data
loads the clock sits at the start, so nothing holds a record yet -- a page that
wants the race's final records asks
[`BestTimes.final`](Motorsport-BestTimes#final) instead.

-}
at : { elapsed : Instant } -> Race -> Snapshot
at clock race =
    let
        records =
            BestTimes.at clock race.bestTimeChanges

        sampled =
            race.cars
                |> List.filterMap (sampleCar clock race)
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
            Ordering.byPosition (.standing >> .position) cars
    in
    Snapshot
        { elapsed = clock.elapsed
        , lapCount = Race.lapCountAt clock race
        , cars = sortedCars
        , carsByClass = groupByClass sortedCars
        , bestTimes = records
        , lapHistory = LapHistory.at clock race.cars
        }


currentSectorStates : Lap.SectorProgress -> SectorPerformance -> CurrentSectorStates
currentSectorStates current rated =
    let
        stateOf sector rating =
            case Sector.compare sector current.sector of
                LT ->
                    Performance.Completed rating

                EQ ->
                    Performance.fromProgress current.progress rating

                GT ->
                    Performance.NotEntered
    in
    Sector.map2 stateOf (Sector.initialize identity) rated


{-| The mini-sector counterpart of [`currentSectorStates`](#currentSectorStates).

A car that cannot be placed reads as past every mini-sector: right for a lap
that is over, wrong for the mid-lap gap [`MiniSectorReading`](#MiniSectorReading)
describes, where the strip fills in ahead of the car.

-}
currentMiniSectorStates : Maybe Lap.MiniSectorProgress -> MiniSectorPerformance -> CurrentMiniSectorStates
currentMiniSectorStates miniSectorProgress rated =
    let
        stateOf mini rating =
            case miniSectorProgress of
                Just current ->
                    case LeMans.compare mini current.miniSector of
                        LT ->
                            Performance.Completed rating

                        EQ ->
                            Performance.fromProgress current.progress rating

                        GT ->
                            Performance.NotEntered

                Nothing ->
                    Performance.Completed rating
    in
    LeMans.map2 stateOf (LeMans.initialize identity) rated


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

A scan rather than an index: an index would be built every frame whether
anything asked for a car or not. Two cars sharing a number -- which the source
data occasionally has -- give the one running ahead.

-}
get : CarNumber -> Snapshot -> Maybe CarAt
get carNumber (Snapshot s) =
    SortedList.toList s.cars
        |> List.filter (\car -> car.metadata.carNumber == carNumber)
        |> List.head


{-| The cars racing in one class, in running order. A class no car races in is
empty rather than absent.
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
reach for `laps` and `currentLap` directly. The constraint stops at this type;
what comes out the other side is a `CarAt`, which carries neither.

-}
type alias SampledCar =
    Gap.Competitor
        { metadata : Car.Metadata
        , lastLap : Maybe Lap
        , status : Status
        , currentDriver : Driver
        }


{-| Read a car at the clock, where it is running.

`Nothing` for a car with no lap in progress, which is one that has turned no lap
at all. Such a car is not in the field, and settling that here is what lets
everything downstream -- `Ordering.runningOrder`, `Gap.Competitor`, `CarAt` --
ask for a lap rather than a `Maybe` of one.

-}
sampleCar : { elapsed : Instant } -> Race -> Car -> Maybe SampledCar
sampleCar clock race car =
    Lap.findCurrentLap clock car.laps
        |> Maybe.map
            (\lap ->
                { metadata = car.metadata
                , laps = car.laps
                , currentLap = lap
                , lastLap = Lap.findLastLapAt clock car.laps
                , status = Race.statusAt clock car.metadata.carNumber race
                , currentDriver = lap.driver
                }
            )


type alias Timing =
    { currentLapElapsed : Duration
    , gapToLeader : Gap
    , intervalToAhead : Gap
    }


timingOf : Instant -> { leader : Maybe SampledCar, rival : Maybe SampledCar } -> SampledCar -> Timing
timingOf raceElapsed rivals car =
    let
        raceClock =
            { elapsed = raceElapsed }
    in
    { currentLapElapsed =
        Instant.since
            { from =
                -- A car on its opening lap began where the race did.
                case car.lastLap of
                    Just lap ->
                        lap.elapsed

                    Nothing ->
                        Instant.raceStart
            , to = raceClock.elapsed
            }
    , gapToLeader = gapTo raceClock car rivals.leader
    , intervalToAhead = gapTo raceClock car rivals.rival
    }


readCurrentLap :
    { clock : { elapsed : Instant }
    , records : BestTimes.Snapshot
    , fastestLapTime : Maybe Duration
    , personalBest : Maybe Duration
    , elapsed : Duration
    }
    -> Lap
    -> CurrentLap
readCurrentLap frame lap =
    let
        sector =
            let
                sectorProgress =
                    Lap.progressAt frame.clock lap
            in
            { sectorProgress | progress = min 1 sectorProgress.progress }

        miniSectors =
            Performance.ofMiniSectors frame.records lap
                |> Maybe.map
                    (\rated ->
                        let
                            current =
                                Lap.miniSectorProgressAt frame.clock lap
                        in
                        Recorded
                            { states = currentMiniSectorStates current rated
                            , current = current
                            }
                    )
                |> Maybe.withDefault NotRecorded
    in
    { elapsed = frame.elapsed
    , progress =
        -- Against the lap's eventual time, the one figure of this lap the clock
        -- has not reached.
        lap.time
            |> Maybe.map (\lapTime -> min 1.0 (toFloat frame.elapsed / toFloat lapTime))
            |> Maybe.withDefault 0
    , performance =
        Performance.performanceLevel
            { time = frame.elapsed
            , personalBest = frame.personalBest
            , fastest = frame.fastestLapTime
            }
    , sector = sector
    , sectorStates = currentSectorStates sector (Performance.ofSectors frame.records lap)
    , miniSectors = miniSectors
    }


gapTo : { elapsed : Instant } -> SampledCar -> Maybe SampledCar -> Gap
gapTo raceClock car ahead =
    ahead
        |> Maybe.map (\aheadCar -> Gap.at raceClock { ahead = aheadCar, behind = car })
        |> Maybe.withDefault Gap.none


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
other car to fall back on a position it does not hold.

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

        -- A lap's `best` counts its own time, so reading it off the finished
        -- lap is what stops the lap in progress being rated against itself.
        personalBest =
            car.lastLap |> Maybe.andThen .best
    in
    { metadata = car.metadata
    , status = car.status
    , currentDriver = car.currentDriver
    , standing =
        { position = placed.position
        , positionInClass = placed.positionInClass
        , lapsCompleted = car.lastLap |> Maybe.map .lap |> Maybe.withDefault 0
        , gapToLeader = timing.gapToLeader
        , intervalToAhead = timing.intervalToAhead
        }
    , currentLap =
        readCurrentLap
            { clock = { elapsed = frame.raceElapsed }
            , records = frame.records
            , fastestLapTime = frame.fastestLapTime
            , personalBest = personalBest
            , elapsed = timing.currentLapElapsed
            }
            car.currentLap
    , lastLap =
        case car.lastLap of
            Just lap ->
                Completed
                    { rated =
                        Performance.rateTime frame.fastestLapTime
                            { time = lap.time, personalBest = lap.best }
                    , sectors = Performance.ofSectors frame.records lap
                    , miniSectors = Performance.ofMiniSectors frame.records lap
                    }

            Nothing ->
                NoLapYet
    , bestLap =
        Performance.rateTime frame.fastestLapTime
            { time = personalBest, personalBest = personalBest }
    }
