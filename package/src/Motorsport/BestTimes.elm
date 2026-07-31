module Motorsport.BestTimes exposing
    ( BestTimes, Snapshot
    , empty, fromLaps
    , at, final
    )

{-| When each of the race's best times was set, and what they stand at.

Twenty records make up the baseline a timing screen rates against: the fastest
lap, three sectors, fifteen mini-sectors, and the slowest lap that the other end
of the scale is drawn against. Each is a
[`ChangePoints`](Motorsport-Internal-ChangePoints) over the moments it was
beaten, which is what keeps reading the baseline off a binary search rather than
twenty passes over every lap of the race.

The module sits beside [`Lap`](Motorsport-Lap) and [`Gap`](Motorsport-Gap)
rather than under either side it serves, because both sides need it and neither
owns it: [`Race`](Motorsport-Race) builds the records once and holds them, and
[`ViewModel`](Motorsport-ViewModel) reads them back at the clock. Laps in, times
out -- it knows nothing of cars, standings or playback, which is what keeps the
dependency pointing one way from both.

@docs BestTimes, Snapshot
@docs empty, fromLaps
@docs at, final

-}

import Motorsport.Circuit.LeMans as LeMans exposing (ByMiniSector, LeMans2025MiniSector)
import Motorsport.Duration exposing (Duration)
import Motorsport.Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Motorsport.Lap exposing (Lap)
import Motorsport.Sector as Sector exposing (BySector, Sector)


{-| The whole race's records, each one as a history of when it changed.
-}
type alias BestTimes =
    ByRecord (ChangePoints Duration)


{-| The same records as they stood at one moment -- the comparison baseline a
widget rates and scales individual times against.

A record no lap has set yet reads `0`, so a caller that would have to unwrap a
`Maybe` on all twenty of them does not have to.

-}
type alias Snapshot =
    ByRecord Duration


{-| One value per record: the shape the two types above share, differing only in
what they hold.

Everything this module does to the twenty records -- building them, reading them,
emptying them -- goes through `map`, so they are enumerated in exactly one place.
Adding a record is two lines: what it holds, here, and how it is won, in `rules`.

-}
type alias ByRecord a =
    { fastestLapTime : a
    , slowestLapTime : a
    , fastestSectors : BySector a
    , fastestMiniSectors : ByMiniSector a
    }


map : (a -> b) -> ByRecord a -> ByRecord b
map f records =
    { fastestLapTime = f records.fastestLapTime
    , slowestLapTime = f records.slowestLapTime
    , fastestSectors = Sector.initialize (\sector -> f (Sector.get sector records.fastestSectors))
    , fastestMiniSectors = LeMans.initialize (\mini -> f (LeMans.get mini records.fastestMiniSectors))
    }


{-| No laps recorded yet. Every reading comes back `Nothing`, so every snapshot
of it reads zero.
-}
empty : BestTimes
empty =
    fromLaps []


{-| Read the records off every lap of a race, however the laps arrive.

Whose lap is whose does not come into it: a record belongs to the race, and the
only thing that decides which lap set it is when it was completed.

-}
fromLaps : List Lap -> BestTimes
fromLaps laps =
    let
        -- In the order the laps were completed, which is the order the records
        -- were set in.
        inOrder =
            List.sortBy .elapsed laps
    in
    map (\{ beats, timeFrom } -> improvements beats timeFrom inOrder) rules


{-| The records as they stood at a moment of the race: what a car crossing the
line then was rated against.
-}
at : { elapsed : Duration } -> BestTimes -> Snapshot
at clock =
    map (ChangePoints.valueAt clock.elapsed >> Maybe.withDefault 0)


{-| The records as the race left them, without having to name a time past the
end of it.
-}
final : BestTimes -> Snapshot
final =
    map (ChangePoints.last >> Maybe.withDefault 0)



-- WHAT EACH RECORD COMPETES FOR


{-| What sets one record apart from another: which of a lap's times it is drawn
from, and which way round a time has to be to beat the standing one.
-}
type alias Rule =
    { beats : Duration -> Duration -> Bool
    , timeFrom : Lap -> Maybe Duration
    }


rules : ByRecord Rule
rules =
    { fastestLapTime = { beats = lessThan, timeFrom = recordedLapTime }
    , slowestLapTime = { beats = greaterThan, timeFrom = lapTimeAsFound }
    , fastestSectors =
        Sector.initialize (\sector -> { beats = lessThan, timeFrom = recordedSectorTime sector })
    , fastestMiniSectors =
        LeMans.initialize (\mini -> { beats = lessThan, timeFrom = recordedMiniSectorTime mini })
    }


{-| Walk the laps in the order they were completed, keeping the time each time
`beats` says the standing one has been improved on.

The `List.reverse` at the end is not cosmetic. The fold prepends, so without it
the improvements would reach `ChangePoints.fromList` newest-first -- and since
that sorts stably and reads the _last_ of any changes sharing a timestamp, two
records set on the same instant would resolve to the earlier one.

-}
improvements :
    (Duration -> Duration -> Bool)
    -> (Lap -> Maybe Duration)
    -> List Lap
    -> ChangePoints Duration
improvements beats timeFrom laps =
    laps
        |> List.foldl
            (\lap ( standing, collected ) ->
                case ( timeFrom lap, standing ) of
                    ( Nothing, _ ) ->
                        ( standing, collected )

                    ( Just time, Nothing ) ->
                        ( Just time, ( lap.elapsed, time ) :: collected )

                    ( Just time, Just standingTime ) ->
                        if beats time standingTime then
                            ( Just time, ( lap.elapsed, time ) :: collected )

                        else
                            ( standing, collected )
            )
            ( Nothing, [] )
        |> Tuple.second
        |> List.reverse
        |> ChangePoints.fromList


lessThan : Duration -> Duration -> Bool
lessThan a b =
    a < b


greaterThan : Duration -> Duration -> Bool
greaterThan a b =
    a > b



-- WHAT COUNTS AS A TIME
-- A zero is a time the source data did not record, not a very quick one, so it
-- is no candidate for a fastest anything. Every extractor below says `recorded`
-- to mean it drops those -- all but one, and that one says what it does instead.


recordedLapTime : Lap -> Maybe Duration
recordedLapTime lap =
    recorded lap.time


{-| The exception: a zero can only win a maximum when there is nothing to beat,
so the slowest lap takes every lap as it finds it.
-}
lapTimeAsFound : Lap -> Maybe Duration
lapTimeAsFound lap =
    Just lap.time


recordedSectorTime : Sector -> Lap -> Maybe Duration
recordedSectorTime sector lap =
    recorded (Sector.get sector lap.sectors).time


{-| Mini-sector times are only trusted on laps that have a lap time, matching
what the whole-race calculation has always done.
-}
recordedMiniSectorTime : LeMans2025MiniSector -> Lap -> Maybe Duration
recordedMiniSectorTime mini lap =
    case recorded lap.time of
        Just _ ->
            lap.miniSectors
                |> Maybe.andThen (LeMans.get mini >> .time)
                |> Maybe.andThen recorded

        Nothing ->
            Nothing


recorded : Duration -> Maybe Duration
recorded time =
    if time == 0 then
        Nothing

    else
        Just time
