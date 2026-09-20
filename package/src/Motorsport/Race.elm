module Motorsport.Race exposing
    ( Race
    , Index, emptyIndex, indexDecoder
    , empty, fromCars
    , lapCountAt, elapsedAtLapCount, timeToFlagAt
    , statusAt, pitStopsAt
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
@docs statusAt, pitStopsAt

-}

import Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Json.Decode as Decode exposing (Decoder, field)
import List.Extra
import Motorsport.BestTimes as BestTimes
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Stint as Stint
import Motorsport.Status as Status exposing (Status)


{-| The three indices read the same race at an instant, and are all
[`ChangePoints`](Internal-ChangePoints) underneath.

`lapTotal` is read off `lapCompletions` rather than counted separately, so the
counter's ceiling and `lapCountAt` can never disagree about how long the race
was.

`lapCompletions` and `bestTimeChanges` come with the round's summary.
`pitStops` is counted here, off the cars: the laps carry both ends of a stop, so
nothing has to be read for it, and neither is anything read for a status.

`timeLimit` is when the race was scheduled to end, and the one thing here the
laps do not say -- it only looks as though they do, being a whole-hour estimate
off the last of them -- so [`fromCars`](#fromCars) is given it. It is also what
tells a car that retired from one that took the flag, neither of which a last
lap says for itself. Where the race actually ran out bounds playback rather than
describing the race, and is [`Clock`](Motorsport-Clock)'s.

-}
type alias Race =
    { cars : List Car
    , lapTotal : Int
    , timeLimit : Instant
    , lapCompletions : ChangePoints Int
    , bestTimeChanges : BestTimes.Changes
    , pitStops : Stint.Index
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
    , lapCompletions = emptyIndex.lapCompletions
    , bestTimeChanges = emptyIndex.bestTimeChanges
    , pitStops = Stint.emptyIndex
    }


{-| Read a race off its entry list and the indices that came with it.
-}
fromCars : { timeLimit : Instant, index : Index } -> List Car -> Race
fromCars { timeLimit, index } cars =
    { cars = cars
    , lapTotal = ChangePoints.length index.lapCompletions
    , timeLimit = timeLimit
    , lapCompletions = index.lapCompletions
    , bestTimeChanges = index.bestTimeChanges
    , pitStops = Stint.indexOf cars
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


{-| How far through its race a car is at a moment of it: away, running, or done.

Both ends come off the car's own laps. It is running from the start until its
final crossing, and from there it has either retired or taken the flag -- which
the laps cannot tell apart, a last lap being a last lap either way, so the
scheduled end of the race is what separates them. A car that turned no lap never
started.

The pit lane is the other half of a status and is read off the laps too, so a
car's whole status is [`Race.Snapshot`](Motorsport-Race-Snapshot)'s rather than
this.

-}
statusAt : { elapsed : Instant } -> Car -> Race -> Status
statusAt clock car race =
    case List.Extra.last car.laps of
        Nothing ->
            Status.PreRace

        Just final ->
            if Instant.compare clock.elapsed final.elapsed == LT then
                Status.Racing

            else if Instant.compare final.elapsed race.timeLimit == LT then
                Status.Retired

            else
                Status.Checkered


{-| How many stops a car has completed at a moment of the race.
-}
pitStopsAt : { elapsed : Instant } -> CarNumber -> Race -> Int
pitStopsAt clock carNumber race =
    Stint.stopsAt clock carNumber race.pitStops
