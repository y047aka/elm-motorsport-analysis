module Motorsport.Race.Snapshot exposing
    ( Snapshot, CarAt, Standing, CurrentLap, LastLap(..), lastLapRating
    , CurrentSectorStates, CurrentMiniSectorStates
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
`get` and `inClass` below -- so that a view narrowing the field says which one
it wants rather than working it out of `toList`.

@docs Snapshot, CarAt, Standing, CurrentLap, LastLap, lastLapRating
@docs CurrentSectorStates, CurrentMiniSectorStates
@docs at
@docs toList, toClassList, get, inClass, leader, lapCount, elapsed
@docs bestTimes, lapHistory

-}

import Dict
import Motorsport.BestTimes as BestTimes
import Motorsport.Circuit.LeMans as LeMans exposing (ByMiniSector)
import Motorsport.Class as Class exposing (Class)
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

Readings only, and no laps: the laps up to this moment are
[`lapHistory`](#lapHistory)'s to give out, already cut. A lap the car has turned
is here as what was read off it -- `standing.lapsCompleted`, and
[`lastLap`](#LastLap) -- rather than as the lap itself.

Grouped by what the reading is of: where the car stands in the field
([`standing`](#Standing)), and what the lap it is on and the one it just
finished read as ([`currentLap`](#CurrentLap), [`lastLap`](#LastLap)). Who the
car is stays at the top.

Every rating here is measured against the records as they stood at this moment,
not as the race leaves them. Two records: the race's, which is
[`bestTimes`](#bestTimes)'s to hold, and the car's own, which is `bestLap` --
and that is what puts `bestLap` outside the groups, since it belongs to no one
lap and every other rating of this car is read against it. See
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

The placings and the gaps are read off the same running order, in one pass; see
[`at`](#at). `lapsCompleted` counts laps the car has finished, so a car on its
opening lap has none.

Both gaps are [`Gap.none`](Motorsport-Gap#none) for the leading car and only for
it: nothing runs ahead of it, and it is what the race is measured to.

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

`elapsed` is how long the car has been on it, counted from the last time it
crossed the line -- or from the race start, for a car on its opening lap.
`performance` is how that reads against the records (see [`CarAt`](#CarAt) for
which), and `progress` how far through the lap it puts the car. `sector` and
`miniSector` say where on the lap the car is; `sectorStates` and
`miniSectorStates` say as much of every sector and every mini-sector at once,
which is what a strip of cells is drawn from.

The mini-sector readings are the only `Maybe`s, for the reason
[`CurrentMiniSectorStates`](#CurrentMiniSectorStates) gives. `miniSector` is
`Nothing` in one case more: a clock past the last mini-sector of the lap is in
none of them.

-}
type alias CurrentLap =
    { elapsed : Duration
    , progress : Float
    , performance : PerformanceLevel
    , sector : Lap.SectorProgress
    , sectorStates : CurrentSectorStates
    , miniSector : Maybe Lap.MiniSectorProgress
    , miniSectorStates : Maybe CurrentMiniSectorStates
    }


{-| The lap the car has just finished, as it was read off it -- where it has
finished one.

A car on its opening lap has nothing behind it, and that is `NoLapYet` rather
than a reading with everything missing: the time, the sectors and the
mini-sectors are absent together or not at all, since they are all read off the
one lap. A view that has nothing to print prints the same "-" for all three.

The lap itself is not here -- see [`CarAt`](#CarAt) -- only what was read: the
time it took and how its sectors went, each rated as every rating on a car is.

The two remaining absences are the other kinds, and stay where they are.
`rated` is `Nothing` for a lap the source data has no time for, as
[`rateTime`](Motorsport-Lap-Performance#rateTime) gives it. `miniSectors` is
`Nothing` away from Le Mans, where the source data records no mini-sectors to
rate.

-}
type LastLap
    = NoLapYet
    | Finished
        { rated : Maybe RatedTime
        , sectors : SectorPerformance
        , miniSectors : Maybe MiniSectorPerformance
        }


{-| The rating of the lap the car has just finished, where it has finished one
and the source data timed it.

The one place the two absences above are flattened together, for the callers
that have nothing to say about either: a column that prints a time or a "-", and
the sort behind it. Anything that draws the sectors reads the `Finished` fields
instead.

-}
lastLapRating : LastLap -> Maybe RatedTime
lastLapRating lastLap_ =
    case lastLap_ of
        Finished { rated } ->
            rated

        NoLapYet ->
            Nothing


{-| Where the car stands in each sector of the lap it is on: whether it has
reached the sector, is inside it, or has the whole of it behind -- and, once it
does, how the time reads. See
[`SegmentState`](Motorsport-Lap-Performance#SegmentState).
-}
type alias CurrentSectorStates =
    BySector SegmentState


{-| The same reading at the finer grain, where the circuit records mini-sectors.

`Nothing` on a [`CurrentLap`](#CurrentLap) rather than empty, because away from
Le Mans there are no mini-sectors to stand anywhere in.

-}
type alias CurrentMiniSectorStates =
    ByMiniSector SegmentState


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
        -- Sectors already driven through are complete, the ones ahead
        -- untouched. Only the one in between reads off the clock, and even that
        -- lands on complete once the car is through it -- see
        -- `Performance.fromProgress`.
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


{-| The mini-sector counterpart of [`currentSectorStates`](#currentSectorStates),
reading the same way: behind the car complete, ahead of it untouched, and no
mini-sector in progress at all meaning the lap is over.

Joined here rather than by the view that draws the strip, as the sectors' is:
a cell wants to know how much of its mini-sector is behind the car and how that
mini-sector rates, and neither is a question about drawing.

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

                -- The clock is past the last mini-sector of the lap, so there
                -- is none the car is in and every one of them is behind it.
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

A scan of the field, which is what a call that comes now and then wants: an
index would be built every frame whether anything asked for a car or not. Two
cars sharing a number -- which the source data occasionally has -- give the one
running ahead, since the field is in running order.

-}
get : CarNumber -> Snapshot -> Maybe CarAt
get carNumber (Snapshot s) =
    SortedList.toList s.cars
        |> List.filter (\car -> car.metadata.carNumber == carNumber)
        |> List.head


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

        -- Named apart from `CarAt.lastLap` deliberately: this is the lap
        -- itself, that one is what was read off it.
        , previousLap : Maybe Lap
        , status : Status
        , currentDriver : Driver
        }


{-| Read a car at the clock, where it is running.

`Nothing` for a car with no lap in progress, which is one that has turned no lap
at all -- a lap stays the car's current one until the next begins. Such a car is
not in the field: there is no answer to where it stands, and nothing to report
of it but its number. Nor can the data produce one, since the loader builds the
entry list out of the lap records themselves.

Settled here once, and everything downstream is written knowing it:
[`Ordering.runningOrder`](Motorsport-Ordering#runningOrder) and
[`Gap.Competitor`](Motorsport-Gap#Competitor) ask for a lap rather than a
`Maybe` of one, and a [`CarAt`](#CarAt) carries its lap plainly.

-}
sampleCar : { elapsed : Instant } -> Race -> Car -> Maybe SampledCar
sampleCar clock race car =
    Lap.findCurrentLap clock car.laps
        |> Maybe.map
            (\lap ->
                { metadata = car.metadata
                , laps = car.laps
                , currentLap = lap
                , previousLap = Lap.findLastLapAt clock car.laps
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
                -- A car on its opening lap has no lap behind it, and that lap
                -- began where the race did.
                case car.previousLap of
                    Just lap ->
                        lap.elapsed

                    Nothing ->
                        Instant.raceStart
            , to = raceClock.elapsed
            }
    , gapToLeader = gapTo raceClock car rivals.leader
    , intervalToAhead = gapTo raceClock car rivals.rival
    }


{-| Read the lap a car is on at this moment.

Only ever called with the lap the car is actually on, which is what lets the
readings that need one be plain rather than `Maybe`: there is a sector the car
is in, and a running time to rate, because there is a lap.

-}
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

        miniSector =
            Lap.miniSectorProgressAt frame.clock lap
    in
    { elapsed = frame.elapsed
    , progress =
        -- Against the lap's eventual time, which is the one figure of this lap
        -- the clock has not reached. It stays inside: what a caller wants of
        -- it is how far round the car has got, not the answer it is measured
        -- against.
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
    , miniSector = miniSector
    , miniSectorStates =
        Performance.ofMiniSectors frame.records lap
            |> Maybe.map (currentMiniSectorStates miniSector)
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

        -- The car's own record at this moment. A lap's `best` counts its own
        -- time, so the lap in progress carries one the clock has not reached;
        -- reading it off the finished lap is what stops the lap being rated
        -- against itself. Read once, so `currentLap.performance`'s baseline and
        -- `bestLap` cannot come apart.
        personalBest =
            car.previousLap |> Maybe.andThen .best
    in
    { metadata = car.metadata
    , status = car.status
    , currentDriver = car.currentDriver
    , standing =
        { position = placed.position
        , positionInClass = placed.positionInClass
        , lapsCompleted = car.previousLap |> Maybe.map .lap |> Maybe.withDefault 0
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
        case car.previousLap of
            Just lap ->
                Finished
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
