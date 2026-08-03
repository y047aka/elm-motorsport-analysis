module Motorsport.Race.Snapshot exposing
    ( Snapshot, CarAt
    , at
    , toList, lapCount, elapsed
    )

{-| A [`Race`](Motorsport-Race) read at one moment of it.

The race itself never moves; a snapshot is what the cars are actually doing once
a clock is applied to it -- which lap each is on, who is ahead of whom, and how
far apart they are. All of it is settled by the race data and the clock alone, so
swapping the view layer out would not change a single number here.

Rebuilt on every frame rather than stored, and built once per frame so the
several views that need the same order and the same gaps do not each work them
out again.

What the view layer renders from this is
[`Standings`](Motorsport-ViewModel-Standings).

@docs Snapshot, CarAt
@docs at
@docs toList, lapCount, elapsed

-}

import Dict exposing (Dict)
import List.Extra
import Motorsport.BestTimes as BestTimes
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (MiniSectorPerformance, RatedTime, SectorPerformance)
import Motorsport.Ordering as Ordering exposing (ByPosition)
import Motorsport.Race as Race exposing (Race)
import Motorsport.Race.Car as Car exposing (Car)
import Motorsport.Status exposing (Status)
import SortedList exposing (SortedList)


{-| Every car of the race as it stands at one moment, in running order.
-}
type Snapshot
    = Snapshot
        { elapsed : Instant
        , lapCount : Int
        , cars : SortedList ByPosition CarAt
        }


{-| One [`Car`](Motorsport-Race-Car) as it stands at one moment of the race.

Written as a [`Gap.Competitor`](Motorsport-Gap#Competitor) with the rest added
on, because that is the shape the ordering depends on: `Gap.at` and
`Ordering.runningOrder` reach for `laps` and `currentLap` directly, so those two
have to stay at the top level rather than nesting inside a `Car`.

-}
type alias CarAt =
    Gap.Competitor
        { metadata : Car.Metadata
        , lastLap : Maybe Lap
        , status : Status
        , currentDriver : Maybe Driver
        , position : Int
        , positionInClass : Int
        , currentLapElapsed : Duration
        , sector : Maybe Lap.SectorProgress
        , miniSector : Maybe Lap.MiniSectorProgress
        , gapToLeader : Gap
        , intervalToAhead : Gap

        -- Rated against the record the race held at this moment; see
        -- [`Lap.Performance`](Motorsport-Lap-Performance).
        , currentLapRated : Maybe RatedTime
        , currentLapSectorsRated : Maybe SectorPerformance
        , lastLapRated : Maybe RatedTime
        , bestLapRated : Maybe RatedTime
        , lastLapSectorsRated : Maybe SectorPerformance
        , lastLapMiniSectorsRated : Maybe MiniSectorPerformance
        }


{-| Read the whole race at a moment of it, against the record it held then.
-}
at : BestTimes.Snapshot -> { elapsed : Instant } -> Race -> Snapshot
at bestTimes clock race =
    let
        -- A car carries only its laps, so what it is doing at this moment is
        -- read off the clock here. Who is ahead of whom follows from that, and
        -- every position below is read off the resulting order.
        sampled =
            race.cars
                |> List.map (sampleCar clock race)
                |> Ordering.runningOrder clock

        leader =
            List.head sampled

        positionsInClass =
            positionsInClassByCarNumber sampled

        fastestLapTime =
            BestTimes.timeOf bestTimes.fastestLapTime

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
                                            leader
                                    , rival = List.Extra.getAt (index - 1) sampled
                                    }
                                    car
                        in
                        { metadata = car.metadata
                        , laps = car.laps
                        , currentLap = car.currentLap
                        , lastLap = car.lastLap
                        , status = car.status
                        , currentDriver = car.currentDriver
                        , position = index + 1
                        , positionInClass =
                            Dict.get car.metadata.carNumber positionsInClass
                                |> Maybe.withDefault 1
                        , currentLapElapsed = timing.currentLapElapsed
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
                        , currentLapSectorsRated =
                            car.currentLap |> Maybe.map (Performance.ofSectors bestTimes)
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
                        , lastLapSectorsRated =
                            car.lastLap |> Maybe.map (Performance.ofSectors bestTimes)
                        , lastLapMiniSectorsRated =
                            car.lastLap |> Maybe.andThen (Performance.ofMiniSectors bestTimes)
                        }
                    )
    in
    Snapshot
        { elapsed = clock.elapsed
        , lapCount = Race.lapCountAt clock race
        , cars = Ordering.byPosition cars
        }


{-| The cars in running order, the leader first.
-}
toList : Snapshot -> List CarAt
toList (Snapshot s) =
    SortedList.toList s.cars


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



-- INTERNALS


{-| A car before the field has been put in order: everything that can be read
from the car alone, without knowing who else is out there.

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
