module Motorsport.Race exposing
    ( Race
    , Index, emptyIndex, indexDecoder
    , empty, fromCars
    , lapCountAt, elapsedAtLapCount, timeToFlagAt
    , statusAt
    )

{-| A race, as it is once the data has loaded: cars, their laps, and the
indices that let any moment of it be read back cheaply.

Nothing here moves. Where playback has got to is
[`Clock`](Motorsport-Clock)'s business, and what the cars are doing at that
moment is derived from the two, in
[`Race.Snapshot`](Motorsport-Race-Snapshot).

@docs Race
@docs Index, emptyIndex, indexDecoder
@docs empty, fromCars
@docs lapCountAt, elapsedAtLapCount, timeToFlagAt
@docs statusAt

-}

import Json.Decode as Decode exposing (Decoder, field)
import Motorsport.BestTimes as BestTimes
import Motorsport.Duration exposing (Duration)
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

`timeLimit` is when the race was scheduled to end, and the one thing here the
laps do not say -- it only looks as though they do, being a whole-hour estimate
off the last of them -- so [`fromCars`](#fromCars) is given it. Where the race
actually ran out bounds playback rather than describing the race, and is
[`Clock`](Motorsport-Clock)'s.

-}
type alias Race =
    { cars : List Car
    , lapTotal : Int
    , timeLimit : Instant
    , timelineEvents : List TimelineEvent
    , statusChanges : StatusChanges
    , lapCompletions : ChangePoints Int
    , bestTimeChanges : BestTimes.Changes
    }


{-| The two indices a round is read with rather than counted out of: when the
lap counter went up, and when each of the twenty records changed hands. Both
arrive with the round's summary, from `Round.Index`.
-}
type alias Index =
    { lapCompletions : ChangePoints Int
    , bestTimeChanges : BestTimes.Changes
    }


{-| The indices of a round that has not loaded yet.
-}
emptyIndex : Index
emptyIndex =
    { lapCompletions = ChangePoints.empty
    , bestTimeChanges = BestTimes.empty
    }


{-| Read the indices as the round's summary spells them out.
-}
indexDecoder : Decoder Index
indexDecoder =
    Decode.map2 Index
        (field "lapCompletions" lapCompletionsDecoder)
        (field "bestTimeChanges" BestTimes.changesDecoder)


lapCompletionsDecoder : Decoder (ChangePoints Int)
lapCompletionsDecoder =
    Decode.list
        (Decode.map2 (\lap elapsed -> ( elapsed, lap ))
            (field "lap" Decode.int)
            (field "elapsed" Instant.decoder)
        )
        |> Decode.map ChangePoints.fromList


{-| A race with no cars, to stand in for one that has not loaded yet.
-}
empty : Race
empty =
    { cars = []
    , lapTotal = 0
    , timeLimit = Instant.raceStart
    , timelineEvents = []
    , statusChanges = StatusChanges.empty
    , lapCompletions = emptyIndex.lapCompletions
    , bestTimeChanges = emptyIndex.bestTimeChanges
    }


{-| Read a race off its entry list and the indices that came with it.

Lead changes are read from `Lap.position`, so cars that arrive without their
per-lap positions assigned produce a timeline with no lead changes in it -- see
[`TimelineEvent.fromCars`](Motorsport-Race-TimelineEvent#fromCars).

-}
fromCars : { timeLimit : Instant, index : Index } -> List Car -> Race
fromCars { timeLimit, index } cars =
    let
        timelineEvents =
            TimelineEvent.fromCars { timeLimit = timeLimit } cars
    in
    { cars = cars
    , lapTotal = ChangePoints.length index.lapCompletions
    , timeLimit = timeLimit
    , timelineEvents = timelineEvents
    , statusChanges = StatusChanges.fromTimelineEvents timelineEvents
    , lapCompletions = index.lapCompletions
    , bestTimeChanges = index.bestTimeChanges
    }


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


{-| How long the race has left to run at a moment of it, and nought once the
flag has fallen -- a moment it can still be read at, the flag falling on a lap
already under way.
-}
timeToFlagAt : { elapsed : Instant } -> Race -> Duration
timeToFlagAt { elapsed } race =
    max 0 (Instant.since { from = elapsed, to = race.timeLimit })


{-| The status a car holds at a moment of the race.
-}
statusAt : { elapsed : Instant } -> CarNumber -> Race -> Status
statusAt clock carNumber race =
    StatusChanges.statusAt clock carNumber race.statusChanges
