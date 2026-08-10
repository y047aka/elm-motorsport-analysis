module Motorsport.Race exposing
    ( Race
    , empty, fromCars
    , lapCountAt, elapsedAtLapCount
    , statusAt
    )

{-| A race, as it is once the data has loaded: cars, their laps, and the
indices that let any moment of it be read back cheaply.

Nothing here moves. Where playback has got to is
[`Clock`](Motorsport-Clock)'s business, and what the cars are doing at that
moment is derived from the two, in
[`Race.Snapshot`](Motorsport-Race-Snapshot).

@docs Race
@docs empty, fromCars
@docs lapCountAt, elapsedAtLapCount
@docs statusAt

-}

import Dict
import Motorsport.BestTimes as BestTimes
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.StatusChanges as StatusChanges exposing (StatusChanges)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (TimelineEvent)
import Motorsport.Status exposing (Status)


{-| `timelineEvents` reads the race as a list of things that happened; the three
beside it read the same race at an instant, and are
[`ChangePoints`](Motorsport-Internal-ChangePoints) underneath.

`lapTotal` is read off `lapCompletions` rather than counted separately, so the
counter's ceiling and `lapCountAt` can never disagree about how long the race
was.

`timeLimit` and `finishedAt` are the two ends the race can be measured to, and
neither is the other: the flag falls at the time limit, on a lap already under
way, so the last car crosses the line after it. Both are given to
[`fromCars`](#fromCars) -- the time limit because the laps do not say it, and
the finish because scanning them a second time to find it would only be reading
back what the file already states.

-}
type alias Race =
    { cars : List Car
    , lapTotal : Int
    , timeLimit : Instant
    , finishedAt : Instant
    , timelineEvents : List TimelineEvent
    , statusChanges : StatusChanges
    , lapCompletions : ChangePoints Int
    , bestTimeChanges : BestTimes.Changes
    }


{-| A race with no cars, to stand in for one that has not loaded yet.
-}
empty : Race
empty =
    { cars = []
    , lapTotal = 0
    , timeLimit = Instant.raceStart
    , finishedAt = Instant.raceStart
    , timelineEvents = []
    , statusChanges = StatusChanges.empty
    , lapCompletions = ChangePoints.empty
    , bestTimeChanges = BestTimes.empty
    }


{-| Read a race off its entry list, building every index once.

Lead changes are read from `Lap.position`, so cars that arrive without their
per-lap positions assigned produce a timeline with no lead changes in it -- see
[`TimelineEvent.fromCars`](Motorsport-Race-TimelineEvent#fromCars).

-}
fromCars : { timeLimit : Instant, finishedAt : Instant } -> List Car -> Race
fromCars { timeLimit, finishedAt } cars =
    let
        timelineEvents =
            TimelineEvent.fromCars { timeLimit = timeLimit } cars

        lapCompletions =
            calcLapCompletions cars
    in
    { cars = cars
    , lapTotal = ChangePoints.length lapCompletions
    , timeLimit = timeLimit
    , finishedAt = finishedAt
    , timelineEvents = timelineEvents
    , statusChanges = StatusChanges.fromTimelineEvents timelineEvents
    , lapCompletions = lapCompletions
    , bestTimeChanges = BestTimes.fromLaps (List.concatMap .laps cars)
    }


{-| When the lap counter goes up, and to what.

The counter reads the leading car's completed laps, so it goes up the moment the
first car of the field crosses the line for a lap -- the earliest `elapsed` among
every lap carrying that number.

-}
calcLapCompletions : List Car -> ChangePoints Int
calcLapCompletions cars =
    cars
        |> List.concatMap .laps
        |> List.foldl
            (\lap earliest ->
                Dict.update lap.lap
                    (Maybe.map (Instant.earlier lap.elapsed)
                        >> Maybe.withDefault lap.elapsed
                        >> Just
                    )
                    earliest
            )
            Dict.empty
        |> Dict.toList
        |> List.map (\( lapNumber, elapsed ) -> ( elapsed, lapNumber ))
        |> ChangePoints.fromList


{-| How many laps the leading car has completed at a moment of the race.
-}
lapCountAt : { elapsed : Instant } -> Race -> Int
lapCountAt clock race =
    ChangePoints.valueAt clock.elapsed race.lapCompletions
        |> Maybe.withDefault 0


{-| Where to put the clock so the lap counter reads `lapCount`: the last instant
it still reads that.

Asked for the final lap, where there is no next one, it gives the moment that
lap was completed instead; asked for a count the race never reached, the start.

-}
elapsedAtLapCount : Int -> Race -> Instant
elapsedAtLapCount lapCount race =
    if lapCount < 0 then
        Instant.raceStart

    else
        case ChangePoints.timeOfNth lapCount race.lapCompletions of
            Just nextCompletion ->
                Instant.subtract 1 nextCompletion

            Nothing ->
                ChangePoints.timeOfNth (ChangePoints.length race.lapCompletions - 1) race.lapCompletions
                    |> Maybe.withDefault Instant.raceStart


{-| The status a car holds at a moment of the race.
-}
statusAt : { elapsed : Instant } -> CarNumber -> Race -> Status
statusAt clock carNumber race =
    StatusChanges.statusAt clock carNumber race.statusChanges
