module Motorsport.Race.Timeline exposing
    ( Timeline
    , empty, fromList
    , countUpTo, latest
    )

{-| The race as a list of things that happened, indexed so the clock can be read
against it without walking it.

The events are in time order, so how many of them have happened by an elapsed
time is a binary search, and the most recent of them are the tail of that count.
Playback reads both on every frame.

@docs Timeline
@docs empty, fromList
@docs countUpTo, latest

-}

import Array exposing (Array)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race.TimelineEvent exposing (TimelineEvent)


type Timeline
    = Timeline (Array TimelineEvent)


{-| A race in which nothing happened.
-}
empty : Timeline
empty =
    Timeline Array.empty


{-| Index the timeline, whatever order it was read in.

The sort is stable, so events sharing an instant keep the order they came in --
the order `Round.Timeline` gathered them in, and the one
[`StatusChanges`](Motorsport-Race-StatusChanges) indexes the same events by.

-}
fromList : List TimelineEvent -> Timeline
fromList events =
    Timeline (Array.fromList (List.sortBy (.elapsed >> Instant.toDuration) events))


{-| How many events have happened by `elapsed`.
-}
countUpTo : Instant -> Timeline -> Int
countUpTo elapsed (Timeline events) =
    search elapsed events 0 (Array.length events)


{-| The last `limit` events of the first `upTo`, newest first.

`upTo` is a count rather than a moment, so a view holding one can hand the same
number back for as long as no event has arrived -- which is what lets the rows
be built behind a `Html.Lazy` thunk.

-}
latest : { upTo : Int, limit : Int } -> Timeline -> List TimelineEvent
latest { upTo, limit } (Timeline events) =
    let
        end =
            clamp 0 (Array.length events) upTo

        start =
            max 0 (end - limit)
    in
    Array.slice start end events
        |> Array.toList
        |> List.reverse


{-| Invariant: every event below `low` is at or before `elapsed`, and every event
from `high` up is after it. The two meet at the count.
-}
search : Instant -> Array TimelineEvent -> Int -> Int -> Int
search elapsed events low high =
    if low >= high then
        low

    else
        let
            mid =
                low + ((high - low) // 2)
        in
        case Array.get mid events of
            Just event ->
                if Instant.compare event.elapsed elapsed /= GT then
                    search elapsed events (mid + 1) high

                else
                    search elapsed events low mid

            Nothing ->
                low
