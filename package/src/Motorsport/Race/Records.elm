module Motorsport.Race.Records exposing
    ( Records
    , empty, fromEntrants
    )

{-| When each of the race's records was set.

The comparison baseline a timing screen rates times against is the fastest lap so
far, the fastest of three sectors, and the fastest of fifteen mini-sectors --
twenty reductions, each over every lap the race has run. Asked directly, on every
frame, that is twenty passes over twenty thousand laps.

A record only moves when it is broken. Over a whole race the fastest lap improves
a few dozen times; a mini-sector a few hundred. So the moments each one changed
are collected once, when the race loads, and reading one back at an elapsed time
is a binary search -- see [`ChangePoints`](Motorsport-Internal-ChangePoints).

`slowestLapTime` is not a record, but it moves the same way and is wanted for the
same reason: it is the other end of the scale times are drawn against.

@docs Records
@docs empty, fromEntrants

-}

import Motorsport.Circuit.LeMans as LeMans exposing (ByMiniSector, LeMans2025MiniSector)
import Motorsport.Duration exposing (Duration)
import Motorsport.Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Motorsport.Lap exposing (Lap)
import Motorsport.Race.Entrant exposing (Entrant)
import Motorsport.Sector as Sector exposing (BySector, Sector)


type alias Records =
    { fastestLapTime : ChangePoints Duration
    , slowestLapTime : ChangePoints Duration
    , fastestSectors : BySector (ChangePoints Duration)
    , fastestMiniSectors : ByMiniSector (ChangePoints Duration)
    }


{-| No laps recorded yet. Every reading comes back `Nothing`.
-}
empty : Records
empty =
    { fastestLapTime = ChangePoints.empty
    , slowestLapTime = ChangePoints.empty
    , fastestSectors = Sector.initialize (always ChangePoints.empty)
    , fastestMiniSectors = LeMans.initialize (always ChangePoints.empty)
    }


fromEntrants : List Entrant -> Records
fromEntrants entrants =
    let
        -- Every lap of the race in the order it was completed, which is the
        -- order the records were set in.
        laps =
            entrants
                |> List.concatMap .laps
                |> List.sortBy .elapsed
    in
    { fastestLapTime = improvements lessThan recordedLapTime laps
    , slowestLapTime = improvements greaterThan lapTimeAsFound laps
    , fastestSectors =
        Sector.initialize (\sector -> improvements lessThan (recordedSectorTime sector) laps)
    , fastestMiniSectors =
        LeMans.initialize (\mini -> improvements lessThan (recordedMiniSectorTime mini) laps)
    }


{-| Walk the laps in the order they were completed, keeping the time each time
`beats` says the standing one has been improved on.

The `List.reverse` at the end is not cosmetic. The fold prepends, so without it
the improvements would reach `ChangePoints.fromList` newest-first -- and since
that sorts stably and reads the *last* of any changes sharing a timestamp, two
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
            (\lap ( standing, improvements ) ->
                case ( timeFrom lap, standing ) of
                    ( Nothing, _ ) ->
                        ( standing, improvements )

                    ( Just time, Nothing ) ->
                        ( Just time, ( lap.elapsed, time ) :: improvements )

                    ( Just time, Just standingTime ) ->
                        if beats time standingTime then
                            ( Just time, ( lap.elapsed, time ) :: improvements )

                        else
                            ( standing, improvements )
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


{-| The exception. The slowest lap takes every lap as it finds it, because a zero
can never win a maximum unless there is nothing else to win against.
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
