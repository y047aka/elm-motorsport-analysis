module Motorsport.Race.Snapshot exposing
    ( Snapshot, CarAt, Standing, CurrentLap, LastLap(..)
    , CurrentSectorStates, CurrentMiniSectorStates, MiniSectorReading(..)
    , at
    , toList, toClassList, get, inClass, leader, classLeader, lapCount, elapsed
    , gapBetween
    , bestTimes, lapHistory
    )

{-| A [`Race`](Motorsport-Race) read at one moment of it.

Built once per frame and shared by every view that reads it.

@docs Snapshot, CarAt, Standing, CurrentLap, LastLap
@docs CurrentSectorStates, CurrentMiniSectorStates, MiniSectorReading
@docs at
@docs toList, toClassList, get, inClass, leader, classLeader, lapCount, elapsed
@docs gapBetween
@docs bestTimes, lapHistory

-}

import Dict
import List.Extra
import Motorsport.BestTimes as BestTimes
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (MiniSectorPerformance, PerformanceLevel, RatedTime, SectorPerformance, SegmentState)
import Motorsport.Position exposing (Position)
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Car as Car exposing (Car, CarNumber)
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Status as Status exposing (Status)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (ByMiniSector)
import Motorsport.Wec.Class as Class exposing (Class)


{-| Every car of the race as it stands at one moment, in running order.
-}
type Snapshot
    = Snapshot
        { elapsed : Instant
        , lapCount : Int
        , cars : List CarAt
        , bestTimes : BestTimes.Snapshot
        , lapHistory : LapHistory
        , carsByClass : List ( Class, List CarAt )
        }


{-| One [`Car`](Motorsport-Race-Car) as it stands at one moment of the race.

Readings only, and no laps: the laps up to this moment are
[`lapHistory`](#lapHistory)'s to give out, already cut.

`pitStops` counts the stops the car has completed, so a car sitting in the pits
reads at the one before the one it is making. See
[`Race.pitStopsAt`](Motorsport-Race#pitStopsAt).

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
    , pitStops : Int
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
    { position : Position
    , positionInClass : Position
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

`sector` is `Nothing` where [`Lap.progressAt`](Motorsport-Lap#progressAt) could
not place the car: the sector it falls in has no recorded time. `sectorStates`
is read apart from it and does not go blank with it -- how much of the lap is
behind the car is something the lap can still say.

-}
type alias CurrentLap =
    { elapsed : Duration
    , progress : Float
    , performance : PerformanceLevel
    , sector : Maybe Lap.SectorProgress
    , sectorStates : CurrentSectorStates
    , miniSectors : MiniSectorReading
    }


{-| Where the car is on its lap at the mini-sector grain, on a circuit timed to
one. `NotRecorded` away from Le Mans.

`current` is `Nothing` wherever [`Lap.miniSegments`](Motorsport-Lap#miniSegments)
could not place the car: past the last mini-sector, and inside one the source
data left without a running total. So it can fall mid-lap, with mini-sectors
still ahead of the car. `states` is read apart from it and does not go blank
with it: it stops at the last mini-sector the lap can place.

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
against the record as it stood then, not as it ends up.

-}
at : { elapsed : Instant } -> Race -> Snapshot
at clock race =
    let
        records =
            BestTimes.at clock race.bestTimeChanges

        sampled =
            race.cars
                |> List.filterMap (sampleCar clock race)
                |> List.sortWith (\a b -> Lap.compareAt clock a.currentLap b.currentLap)

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
            List.sortBy (.standing >> .position) cars
    in
    Snapshot
        { elapsed = clock.elapsed
        , lapCount = Race.lapCountAt clock race
        , cars = sortedCars
        , carsByClass = groupByClass sortedCars
        , bestTimes = records
        , lapHistory = LapHistory.at clock race.cars
        }


{-| Read from how far round the lap the car has got, so that a sector the lap
cannot place -- one the source data has no time for -- reads as not entered
rather than as complete. The strip stops filling where the lap stops being able
to say.

A lap the clock has reached the end of is behind the car whole, blanks and all.

-}
currentSectorStates : { reached : Maybe Lap.SectorProgress, lapIsOver : Bool } -> SectorPerformance -> CurrentSectorStates
currentSectorStates { reached, lapIsOver } rated =
    let
        stateOf sector rating =
            if lapIsOver then
                Performance.Completed rating

            else
                case reached of
                    Just current ->
                        case Sector.compare sector current.sector of
                            LT ->
                                Performance.Completed rating

                            EQ ->
                                Performance.fromProgress current.progress rating

                            GT ->
                                Performance.NotEntered

                    Nothing ->
                        Performance.NotEntered
    in
    Sector.map2 stateOf (Sector.initialize identity) rated


{-| The mini-sector counterpart of [`currentSectorStates`](#currentSectorStates),
under the same rule. A lap short of one running total is short of two
mini-sectors, so the strip stops two before the car and waits there until it
reaches the line.
-}
currentMiniSectorStates : { reached : Maybe Lap.MiniSectorProgress, lapIsOver : Bool } -> MiniSectorPerformance -> CurrentMiniSectorStates
currentMiniSectorStates { reached, lapIsOver } rated =
    let
        stateOf mini rating =
            if lapIsOver then
                Performance.Completed rating

            else
                case reached of
                    Just current ->
                        case LeMans.compare mini current.miniSector of
                            LT ->
                                Performance.Completed rating

                            EQ ->
                                Performance.fromProgress current.progress rating

                            GT ->
                                Performance.NotEntered

                    Nothing ->
                        Performance.NotEntered
    in
    LeMans.map2 stateOf (LeMans.initialize identity) rated


groupByClass : List CarAt -> List ( Class, List CarAt )
groupByClass sortedCars =
    sortedCars
        |> List.Extra.gatherEqualsBy (.metadata >> .class)
        |> List.map (\( first, rest ) -> ( first.metadata.class, first :: rest ))


{-| The cars in running order, the leader first.
-}
toList : Snapshot -> List CarAt
toList (Snapshot s) =
    s.cars


{-| The cars grouped by the class they race in, each group in running order.
-}
toClassList : Snapshot -> List ( Class, List CarAt )
toClassList (Snapshot s) =
    s.carsByClass


{-| One car of the field by its number, where the race has such a car.

Two cars sharing a number -- which the source data occasionally has -- give
the one running ahead.

-}
get : CarNumber -> Snapshot -> Maybe CarAt
get carNumber (Snapshot s) =
    s.cars
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


leader : Snapshot -> Maybe CarAt
leader (Snapshot s) =
    List.head s.cars


classLeader : Class -> Snapshot -> Maybe CarAt
classLeader class snapshot =
    inClass class snapshot |> List.head


{-| How far up or down the road one car is from another: the intervals between
the two, added up along the running order. Each is measured at the same moment,
so the sum is a time on the road; a lap anywhere between the two makes it no
time at all.

Positive where `other` is behind `car`, as a gap on a timing screen is.

-}
gapBetween : CarAt -> CarAt -> Snapshot -> Maybe Duration
gapBetween car other (Snapshot s) =
    let
        positionOf subject =
            List.Extra.findIndex
                (\item -> item.metadata.carNumber == subject.metadata.carNumber)
                s.cars
    in
    Maybe.map2 Tuple.pair (positionOf car) (positionOf other)
        |> Maybe.andThen
            (\( ours, theirs ) ->
                s.cars
                    |> List.drop (min ours theirs + 1)
                    |> List.take (abs (theirs - ours))
                    |> List.map (.standing >> .intervalToAhead >> Gap.toDuration)
                    |> combine
                    |> Maybe.map
                        (\intervals ->
                            if theirs > ours then
                                List.sum intervals

                            else
                                negate (List.sum intervals)
                        )
            )


combine : List (Maybe a) -> Maybe (List a)
combine =
    List.foldr (Maybe.map2 (::)) (Just [])


{-| How many laps the leader has completed at this moment.
-}
lapCount : Snapshot -> Int
lapCount (Snapshot s) =
    s.lapCount


elapsed : Snapshot -> Instant
elapsed (Snapshot s) =
    s.elapsed


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
from the car alone. A [`Gap.Competitor`](Motorsport-Gap#Competitor), since
`Gap.at` reads `laps` and `currentLap` directly.
-}
type alias SampledCar =
    Gap.Competitor
        { metadata : Car.Metadata
        , lastLap : Maybe Lap
        , status : Status
        , currentDriver : Driver
        , pitStops : Int
        }


{-| `Nothing` for a car with no lap in progress, which is one that has turned no
lap at all and is not in the field.
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
                , status = statusOf clock race car lap
                , currentDriver = lap.driver
                , pitStops = Race.pitStopsAt clock car.metadata.carNumber race
                }
            )


{-| Where the car stands, off the two readings of its laps that say it.

Where its race began and ended is [`Race.statusAt`](Motorsport-Race#statusAt)'s.
Where it is within one still being run is the lap in progress: a stop falls at
the head of the lap the car came back out on, so that is the lap carrying it, and
the clock against [`Lap.stopEndedAt`](Motorsport-Lap#stopEndedAt) separates a car
standing in its box from one already rejoining.

-}
statusOf : { elapsed : Instant } -> Race -> Car -> Lap -> Status
statusOf clock race car currentLap =
    case Race.statusAt clock car race of
        Status.Racing ->
            pitPhaseOf clock currentLap

        settled ->
            settled


pitPhaseOf : { elapsed : Instant } -> Lap -> Status
pitPhaseOf clock currentLap =
    case Lap.stopEndedAt currentLap of
        Just droveAway ->
            if Instant.compare clock.elapsed droveAway == LT then
                Status.InPit

            else
                Status.OutLap

        Nothing ->
            Status.Racing


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
            Lap.progressAt frame.clock lap
                |> Maybe.map
                    (\sectorProgress ->
                        { sectorProgress | progress = min 1 sectorProgress.progress }
                    )

        lapIsOver =
            Instant.compare lap.elapsed frame.clock.elapsed /= GT

        miniSectors =
            Performance.ofMiniSectors frame.records lap
                |> Maybe.map
                    (\rated ->
                        Recorded
                            { states =
                                currentMiniSectorStates
                                    { reached = Lap.miniSectorReachedAt frame.clock lap
                                    , lapIsOver = lapIsOver
                                    }
                                    rated
                            , current = Lap.miniSectorProgressAt frame.clock lap
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
    , sectorStates =
        currentSectorStates
            { reached = Lap.reachedAt frame.clock lap
            , lapIsOver = lapIsOver
            }
            (Performance.ofSectors frame.records lap)
    , miniSectors = miniSectors
    }


gapTo : { elapsed : Instant } -> SampledCar -> Maybe SampledCar -> Gap
gapTo raceClock car ahead =
    ahead
        |> Maybe.map (\aheadCar -> Gap.at raceClock { ahead = aheadCar, behind = car })
        |> Maybe.withDefault Gap.none


type alias Placed =
    { car : SampledCar
    , position : Position
    , positionInClass : Position
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
    , pitStops = car.pitStops
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
