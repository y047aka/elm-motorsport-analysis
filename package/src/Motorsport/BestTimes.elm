module Motorsport.BestTimes exposing
    ( Changes, empty, fromLaps
    , Snapshot, Holder
    , at, final, timeOf
    )

{-| When each of the race's best times was set, what they stand at, and who set
them.

Twenty records make up the baseline a timing screen rates against: the fastest
lap, three sectors, fifteen mini-sectors, and the slowest lap that the other end
of the scale is drawn against. Each is a
[`ChangePoints`](Motorsport-Internal-ChangePoints) over the moments it was
beaten, which is what keeps reading the baseline off a binary search rather than
twenty passes over every lap of the race.

The module sits beside [`Lap`](Motorsport-Lap) and [`Gap`](Motorsport-Gap)
rather than under either side it serves, because both sides need it and neither
owns it: [`Race`](Motorsport-Race) builds the records once and holds them, and
[`Race.Snapshot`](Motorsport-Race-Snapshot) reads them back at the clock.

@docs Changes, empty, fromLaps
@docs Snapshot, Holder
@docs at, final, timeOf

-}

import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Motorsport.Lap exposing (Lap)
import Motorsport.Sector as Sector exposing (BySector, Sector)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (ByMiniSector, LeMans2025MiniSector)


{-| Every moment one of the race's records changed hands, collected once.

Named for the changes rather than the times, like the
[`StatusChanges`](Motorsport-Race-StatusChanges) it sits beside in a
[`Race`](Motorsport-Race): what the times actually are at a moment of the race
is a [`Snapshot`](#Snapshot), read back out of this.

-}
type alias Changes =
    ByRecord (ChangePoints Holder)


{-| A record and the lap that set it. `time` is the record itself -- the lap
time, the sector time, the mini-sector time -- not the time of the lap it was
set on, which for a sector record is a different number entirely.
-}
type alias Holder =
    { time : Duration
    , carNumber : String
    , lap : Int
    , driver : Driver
    }


{-| The records held still at one moment of the race -- the baseline a widget
rates times against, and the laps that set them.

Read mid-race via [`at`](#at) these are only the best times _so far_; only
[`final`](#final)'s answer is the race's actual best times. `Nothing` is a
record no lap has taken yet.

-}
type alias Snapshot =
    ByRecord (Maybe Holder)


{-| One value per record: the shape `Changes` and `Snapshot` share.

Everything this module does to the twenty records goes through `map`, so they
are enumerated in exactly one place. Adding a record is two lines: what it
holds, here, and how it is won, in `rules`.

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


{-| No laps recorded yet. Read at any moment, every record comes back `Nothing`.
-}
empty : Changes
empty =
    fromLaps []


{-| Read the records off every lap of a race, however the laps arrive.

Whose lap is whose does not decide anything: a record belongs to the race, and
the only thing that settles which lap took it is when that lap was completed.
The lap that took it is then credited with it -- see [`Holder`](#Holder).

-}
fromLaps : List Lap -> Changes
fromLaps laps =
    let
        -- In the order the laps were completed, which is the order the records
        -- were set in.
        inOrder =
            List.sortBy (.elapsed >> Instant.toDuration) laps
    in
    map (\{ beats, timeFrom } -> improvements beats timeFrom inOrder) rules


{-| The records as they stood at a moment of the race: what a car crossing the
line then was rated against.
-}
at : { elapsed : Instant } -> Changes -> Snapshot
at clock =
    map (ChangePoints.valueAt clock.elapsed)


{-| The records as the race left them, without having to name a time past the
end of it.
-}
final : Changes -> Snapshot
final =
    map ChangePoints.last


{-| One record as a plain time, for callers that want the number and not who set
it.
-}
timeOf : Maybe Holder -> Maybe Duration
timeOf =
    Maybe.map .time



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
    { fastestLapTime = { beats = lessThan, timeFrom = .time }
    , slowestLapTime = { beats = greaterThan, timeFrom = .time }
    , fastestSectors =
        Sector.initialize (\sector -> { beats = lessThan, timeFrom = sectorTime sector })
    , fastestMiniSectors =
        LeMans.initialize (\mini -> { beats = lessThan, timeFrom = miniSectorTime mini })
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
    -> ChangePoints Holder
improvements beats timeFrom laps =
    laps
        |> List.foldl
            (\lap ( standing, collected ) ->
                let
                    setBy time =
                        ( Just time, ( lap.elapsed, holderOf time lap ) :: collected )
                in
                case ( timeFrom lap, standing ) of
                    ( Nothing, _ ) ->
                        ( standing, collected )

                    ( Just time, Nothing ) ->
                        setBy time

                    ( Just time, Just standingTime ) ->
                        if beats time standingTime then
                            setBy time

                        else
                            ( standing, collected )
            )
            ( Nothing, [] )
        |> Tuple.second
        |> List.reverse
        |> ChangePoints.fromList


holderOf : Duration -> Lap -> Holder
holderOf time lap =
    { time = time
    , carNumber = lap.carNumber
    , lap = lap.lap
    , driver = lap.driver
    }


lessThan : Duration -> Duration -> Bool
lessThan a b =
    a < b


greaterThan : Duration -> Duration -> Bool
greaterThan a b =
    a > b



-- WHAT COUNTS AS A TIME


sectorTime : Sector -> Lap -> Maybe Duration
sectorTime sector lap =
    (Sector.get sector lap.sectors).time


{-| Mini-sector times are only trusted on laps that have a lap time, matching
what the whole-race calculation has always done.
-}
miniSectorTime : LeMans2025MiniSector -> Lap -> Maybe Duration
miniSectorTime mini lap =
    case lap.time of
        Just _ ->
            lap.miniSectors
                |> Maybe.andThen (LeMans.get mini >> .time)

        Nothing ->
            Nothing
