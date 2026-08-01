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
[`ViewModel.Standings`](Motorsport-ViewModel-Standings).

@docs Race
@docs empty, fromCars
@docs lapCountAt, elapsedAtLapCount
@docs statusAt

-}

import Dict
import List.Extra
import Motorsport.BestTimes as BestTimes
import Motorsport.Duration exposing (Duration)
import Motorsport.Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.StatusChanges as StatusChanges exposing (StatusChanges)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (TimelineEvent)
import Motorsport.Status exposing (Status)


{-| `timelineEvents` is kept for the Events tab, which reads the race as a list of
things that happened. The three beside it read the same race at an instant, and
are named for what each records the moments of: `statusChanges` when a car's
status moved, `lapCompletions` when the lap counter went up, `bestTimeChanges`
when a record was set. All three are
[`ChangePoints`](Motorsport-Internal-ChangePoints) underneath.

`lapTotal` is read off `lapCompletions` rather than counted separately, so the
counter's ceiling and `lapCountAt` can never disagree about how long the race was.

-}
type alias Race =
    { cars : List Car
    , lapTotal : Int
    , timeLimit : Duration
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
    , timeLimit = 0
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
fromCars : List Car -> Race
fromCars cars =
    let
        timelineEvents =
            TimelineEvent.fromCars cars

        lapCompletions =
            calcLapCompletions cars
    in
    { cars = cars
    , lapTotal = ChangePoints.length lapCompletions
    , timeLimit = calcTimeLimit cars
    , timelineEvents = timelineEvents
    , statusChanges = StatusChanges.fromTimelineEvents timelineEvents
    , lapCompletions = lapCompletions
    , bestTimeChanges = BestTimes.fromLaps (List.concatMap .laps cars)
    }


calcTimeLimit : List Car -> Duration
calcTimeLimit =
    List.map (.laps >> List.Extra.last >> Maybe.map .elapsed)
        >> List.filterMap identity
        >> List.maximum
        >> Maybe.map (\timeLimit -> (timeLimit // (60 * 60 * 1000)) * 60 * 60 * 1000)
        >> Maybe.withDefault 0


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
                    (Maybe.map (min lap.elapsed)
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
lapCountAt : { elapsed : Duration } -> Race -> Int
lapCountAt clock race =
    ChangePoints.valueAt clock.elapsed race.lapCompletions
        |> Maybe.withDefault 0


{-| Where to put the clock so the lap counter reads `lapCount`.

The last instant it still reads that -- the moment before the next lap is
completed. Asked for the final lap, where there is no next one, it gives the
moment that lap was completed instead. Asked for a count the race never reached,
it gives the start.

Total on its own, so a caller does not have to have checked the range first.

-}
elapsedAtLapCount : Int -> Race -> Duration
elapsedAtLapCount lapCount race =
    if lapCount < 0 then
        0

    else
        case ChangePoints.timeOfNth lapCount race.lapCompletions of
            Just nextCompletion ->
                nextCompletion - 1

            Nothing ->
                ChangePoints.timeOfNth (ChangePoints.length race.lapCompletions - 1) race.lapCompletions
                    |> Maybe.withDefault 0


{-| The status a car holds at a moment of the race.
-}
statusAt : { elapsed : Duration } -> CarNumber -> Race -> Status
statusAt clock carNumber race =
    StatusChanges.statusAt clock carNumber race.statusChanges
