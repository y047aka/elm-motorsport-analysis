module Motorsport.Race exposing
    ( Race
    , Index, emptyIndex, indexDecoder
    , empty, fromCars
    , lapCountAt, timeToFlagAt
    , FlagPeriod, flagAt, flagPeriods
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
@docs lapCountAt, timeToFlagAt
@docs FlagPeriod, flagAt, flagPeriods
@docs statusAt, pitStopsAt

-}

import Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Json.Decode as Decode exposing (Decoder, field)
import List.Extra
import Motorsport.BestTimes as BestTimes
import Motorsport.Duration exposing (Duration)
import Motorsport.Flag as Flag exposing (Flag(..))
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Stint as Stint
import Motorsport.Status as Status exposing (Status)


{-| The four indices read the same race at an instant, and are all
[`ChangePoints`](Internal-ChangePoints) underneath.

`lapCompletions`, `bestTimeChanges` and `flagChanges` come with the round's
summary; `pitStops` is counted here, off the cars.

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
    , flagChanges : ChangePoints Flag
    , pitStops : Stint.Index
    }


{-| The three indices a round is read with rather than counted out of: when the
lap counter went up, when each of the nineteen records changed hands, and when
the field's flag changed. All three arrive with the round's summary, from
`Round.Index`.
-}
type alias Index =
    { lapCompletions : ChangePoints Int
    , bestTimeChanges : BestTimes.Changes
    , flagChanges : ChangePoints Flag
    }


{-| The indices of a round that has not loaded yet.
-}
emptyIndex : Index
emptyIndex =
    { lapCompletions = ChangePoints.empty
    , bestTimeChanges = BestTimes.empty
    , flagChanges = ChangePoints.empty
    }


{-| Read the indices as the round's summary spells them out.
-}
indexDecoder : Decoder Index
indexDecoder =
    Decode.map3 Index
        (field "lapCompletions" lapCompletionsDecoder)
        (field "bestTimeChanges" BestTimes.changesDecoder)
        (field "flagChanges" flagChangesDecoder)


lapCompletionsDecoder : Decoder (ChangePoints Int)
lapCompletionsDecoder =
    Decode.list
        (Decode.map2 (\lap elapsed -> ( elapsed, lap ))
            (field "lap" Decode.int)
            (field "elapsed" Instant.decoder)
        )
        |> Decode.map ChangePoints.fromList


{-| A flag this app has no name for fails the round, as an unknown timeline
event does: a flag dropped in silence would read as racing under green.
-}
flagChangesDecoder : Decoder (ChangePoints Flag)
flagChangesDecoder =
    Decode.list
        (Decode.map2 Tuple.pair
            (field "elapsed" Instant.decoder)
            (field "flag" Decode.string
                |> Decode.andThen
                    (\name ->
                        case Flag.fromString name of
                            Just flag ->
                                Decode.succeed flag

                            Nothing ->
                                Decode.fail ("Unknown flag: " ++ name)
                    )
            )
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
    , flagChanges = emptyIndex.flagChanges
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
    , flagChanges = index.flagChanges
    , pitStops = Stint.indexOf cars
    }


{-| How many laps the leading car has completed at a moment of the race.
-}
lapCountAt : { elapsed : Instant } -> Race -> Int
lapCountAt clock race =
    ChangePoints.valueAt clock.elapsed race.lapCompletions
        |> Maybe.withDefault 0


{-| A flag from the moment it was shown until the next one replaced it.
`until` is `Nothing` for a flag nothing replaced before the race ran out.
-}
type alias FlagPeriod =
    { flag : Flag, from : Instant, until : Maybe Instant }


{-| The flag the field is under at a moment of the race. The race starts under
green, so it is green until race control has shown any.
-}
flagAt : { elapsed : Instant } -> Race -> Flag
flagAt clock race =
    ChangePoints.valueAt clock.elapsed race.flagChanges
        |> Maybe.withDefault GreenFlag


{-| Every flag race control showed, in the order it showed them. A flag that
follows another without a green between them ends it, so a full course yellow
turned into a safety car is two periods, not one inside the other.
-}
flagPeriods : Race -> List FlagPeriod
flagPeriods race =
    let
        changes =
            ChangePoints.toList race.flagChanges
    in
    List.map2 (\( from, flag ) until -> { flag = flag, from = from, until = until })
        changes
        (List.map (Tuple.first >> Just) (List.drop 1 changes) ++ [ Nothing ])


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
