module Motorsport.Race exposing
    ( Race
    , empty, fromEntrants
    , lapCountAt, elapsedAtLapCount
    , statusAt
    )

{-| A race, as it is once the data has loaded: entrants, their laps, and the
indices that let any moment of it be read back cheaply.

Nothing here moves. Where playback has got to is
[`Clock`](Motorsport-Clock)'s business, and what the cars are doing at that
moment is derived from the two -- see [`Car.at`](Motorsport-Car#at).

@docs Race
@docs empty, fromEntrants
@docs lapCountAt, elapsedAtLapCount
@docs statusAt

-}

import Dict
import List.Extra
import Motorsport.Car as Car
import Motorsport.Duration exposing (Duration)
import Motorsport.Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Motorsport.Race.Entrant exposing (CarNumber, Entrant)
import Motorsport.Race.Records as Records exposing (Records)
import Motorsport.Race.StatusIndex as StatusIndex exposing (StatusIndex)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (TimelineEvent)


{-| `timelineEvents` is kept for the Events tab, which reads the race as a list of
things that happened. The indices beside it are for reading it at an instant.
-}
type alias Race =
    { entrants : List Entrant
    , lapTotal : Int
    , timeLimit : Duration
    , timelineEvents : List TimelineEvent
    , statusIndex : StatusIndex
    , lapCompletions : ChangePoints Int
    , records : Records
    }


{-| A race with no entrants, to stand in for one that has not loaded yet.
-}
empty : Race
empty =
    { entrants = []
    , lapTotal = 0
    , timeLimit = 0
    , timelineEvents = []
    , statusIndex = StatusIndex.empty
    , lapCompletions = ChangePoints.empty
    , records = Records.empty
    }


{-| Read a race off its entry list, building every index once.
-}
fromEntrants : List Entrant -> Race
fromEntrants entrants =
    let
        timelineEvents =
            TimelineEvent.fromEntrants entrants
    in
    { entrants = entrants
    , lapTotal = calcLapTotal entrants
    , timeLimit = calcTimeLimit entrants
    , timelineEvents = timelineEvents
    , statusIndex = StatusIndex.fromTimelineEvents timelineEvents
    , lapCompletions = calcLapCompletions entrants
    , records = Records.fromEntrants entrants
    }


calcLapTotal : List Entrant -> Int
calcLapTotal entrants =
    entrants
        |> List.map (.laps >> List.length)
        |> List.maximum
        |> Maybe.withDefault 0


calcTimeLimit : List Entrant -> Duration
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

This is the index that replaces scanning all fifty-odd cars' lap lists on every
frame just to answer "which lap are we on".

-}
calcLapCompletions : List Entrant -> ChangePoints Int
calcLapCompletions entrants =
    entrants
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
lapCountAt : Duration -> Race -> Int
lapCountAt elapsed race =
    ChangePoints.valueAt elapsed race.lapCompletions
        |> Maybe.withDefault 0


{-| Where to put the clock so the lap counter reads `lapCount`.

The last instant it still reads that -- the moment before the next lap is
completed. Asked for the final lap, where there is no next one, it gives the
moment that lap was completed instead.

-}
elapsedAtLapCount : Int -> Race -> Duration
elapsedAtLapCount lapCount race =
    case ChangePoints.timeOf lapCount race.lapCompletions of
        Just nextCompletion ->
            nextCompletion - 1

        Nothing ->
            ChangePoints.timeOf (ChangePoints.length race.lapCompletions - 1) race.lapCompletions
                |> Maybe.withDefault 0


{-| The status a car holds at a moment of the race.
-}
statusAt : { elapsed : Duration } -> CarNumber -> Race -> Car.Status
statusAt clock carNumber race =
    StatusIndex.statusAt clock carNumber race.statusIndex
