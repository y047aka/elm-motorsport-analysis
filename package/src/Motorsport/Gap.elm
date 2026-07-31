module Motorsport.Gap exposing
    ( Gap
    , none, seconds, laps
    , Competitor, at
    , toString
    , toDuration, isWithin
    )

{-|

@docs Gap
@docs none, seconds, laps


## Measuring a gap

@docs Competitor, at


## Reading a gap

@docs toString
@docs toDuration, isWithin

-}

import List.Extra
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap as Lap exposing (Lap)


{-| How far one car is behind another at a moment of the race: a time, a whole
number of laps, or nothing at all — there is no car ahead, or the two have not
driven enough of the race to be compared.

The type is opaque because only some of those numbers say anything about a race.
A gap of `-1.234`, or of zero laps, is not a position on the road; it is
[`at`](#at) called with the two cars the wrong way round. Build gaps with
[`none`](#none), [`seconds`](#seconds) and [`laps`](#laps), which collapse the
meaningless cases to `none`.

-}
type Gap
    = None
    | Seconds Duration
    | Laps Int


{-| No gap to report.

    toString none
    --> "-"

-}
none : Gap
none =
    None


{-| A gap measured in time. A car cannot be behind by a negative amount — that
reading means the car said to be behind is in fact ahead:

    seconds (-500)
    --> none

-}
seconds : Duration -> Gap
seconds duration =
    if duration < 0 then
        None

    else
        Seconds duration


{-| A gap measured in whole laps. Being ahead by no laps at all is a gap in
seconds rather than in laps, so anything short of one lap collapses:

    laps 0
    --> none

-}
laps : Int -> Gap
laps count =
    if count < 1 then
        None

    else
        Laps count


{-| A moment of the race, as [`Lap`](Motorsport-Lap) measures it.
-}
type alias Clock =
    { elapsed : Duration }



-- MEASURING A GAP


{-| Whatever carries a lap history and a lap in progress. The standings' own
car state is the only one in the app; measuring a gap needs nothing else from
it.
-}
type alias Competitor a =
    { a | currentLap : Maybe Lap, laps : List Lap }


{-| The gap between two cars at a moment of the race, seen from the car behind.

`ahead` is the car being chased — the leader, or whoever is next up the road.
The result is what belongs against `behind` on a timing screen: a time while the
two are on the same lap, and a number of laps once they are not.

Both cars are read at `clock`, so the answer follows the race as it plays back.

-}
at : Clock -> { ahead : Competitor a, behind : Competitor b } -> Gap
at clock cars =
    case lapsBetween clock cars of
        0 ->
            secondsBetween clock cars

        lapDiff ->
            laps lapDiff


{-| How many laps `ahead` has on `behind` — as the race runs, not as the lap
counter reads.

The moment the car in front crosses the line its lap number goes up, which on
the counter alone looks like a whole lap over a car a few seconds back. It only
counts as a lap once the car in front has come back round to where the car
behind is now.

-}
lapsBetween : Clock -> { ahead : Competitor a, behind : Competitor b } -> Int
lapsBetween clock { ahead, behind } =
    let
        currentSector =
            Maybe.map (Lap.currentSector clock) behind.currentLap

        hasComeBackRound =
            Maybe.map3
                (\sector aheadLap behindLap ->
                    Lap.sectorStart sector aheadLap < Lap.sectorStart sector behindLap
                )
                currentSector
                ahead.currentLap
                behind.currentLap
                |> Maybe.withDefault False
    in
    case Maybe.map2 (\aheadLap behindLap -> aheadLap.lap - behindLap.lap) ahead.currentLap behind.currentLap of
        Nothing ->
            0

        Just 0 ->
            0

        Just lapDiff ->
            if hasComeBackRound then
                lapDiff

            else
                lapDiff - 1


{-| How long ago `ahead` was where `behind` is now, measured from the start of
the sector `behind` is driving.

Both cars are read on the lap `behind` is on, which is why the lap in front
comes out of `ahead.laps` rather than off its `currentLap`: with no lap between
the two, the car in front may still have just crossed the line onto the next one.

This only means anything once [`lapsBetween`](#lapsBetween) has found no lap
between the cars.

-}
secondsBetween : Clock -> { ahead : Competitor a, behind : Competitor b } -> Gap
secondsBetween clock { ahead, behind } =
    case behind.currentLap of
        Just behindLap ->
            let
                currentSector =
                    Lap.currentSector clock behindLap
            in
            ahead.laps
                |> List.Extra.find (\lap -> lap.lap == behindLap.lap)
                |> Maybe.map
                    (\aheadLap ->
                        seconds (Lap.sectorStart currentSector behindLap - Lap.sectorStart currentSector aheadLap)
                    )
                |> Maybe.withDefault none

        Nothing ->
            none



-- READING A GAP


{-| Render a gap the way a timing screen does. For display only.

    toString (seconds 4321)
    --> "+ 4.321"

    toString (laps 1)
    --> "+ 1 Lap"

    toString (laps 2)
    --> "+ 2 Laps"

-}
toString : Gap -> String
toString gap =
    case gap of
        None ->
            "-"

        Seconds duration ->
            "+ " ++ Duration.toString duration

        Laps 1 ->
            "+ 1 Lap"

        Laps count ->
            "+ " ++ String.fromInt count ++ " Laps"


{-| The time a gap stands for, if it is a time at all. Laps do not convert —
how long a lap takes is the cars' business, not the gap's.

    toDuration (seconds 1500)
    --> Just 1500

    toDuration (laps 1)
    --> Nothing

-}
toDuration : Gap -> Maybe Duration
toDuration gap =
    case gap of
        None ->
            Nothing

        Seconds duration ->
            Just duration

        Laps _ ->
            Nothing


{-| Whether a gap is a time, and no longer than the given one. A gap in laps is
never within a time, however large that time is.

    isWithin 1500 (seconds 1200)
    --> True

    isWithin 1500 (laps 1)
    --> False

-}
isWithin : Duration -> Gap -> Bool
isWithin limit =
    toDuration
        >> Maybe.map (\duration -> duration <= limit)
        >> Maybe.withDefault False
