module Motorsport.Lap exposing
    ( Lap, empty
    , SectorTime, SectorTimes
    , MiniSectors, MiniSectorTime
    , recorded
    , compareAt
    , completedLapsAt, findLastLapAt, findCurrentLap
    , Segment, segments, sectorStart
    , SectorProgress, progressAt, currentSector
    , MiniSectorProgress, miniSegments, currentMiniSector, miniSectorProgressAt, miniSectorStart
    )

{-|

@docs Lap, empty
@docs SectorTime, SectorTimes
@docs MiniSectors, MiniSectorTime
@docs recorded
@docs compareAt
@docs completedLapsAt, findLastLapAt, findCurrentLap


## Sectors as segments of the lap

@docs Segment, segments, sectorStart


## Where the car is on the lap

@docs SectorProgress, progressAt, currentSector
@docs MiniSectorProgress, miniSegments, currentMiniSector, miniSectorProgressAt, miniSectorStart

-}

import Compare exposing (Comparator)
import List.Extra
import Motorsport.Circuit.LeMans as LeMans exposing (ByMiniSector, LeMans2025MiniSector)
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Sector as Sector exposing (BySector, Sector(..))


type alias Lap =
    { carNumber : String
    , driver : Driver
    , lap : Int
    , position : Maybe Int
    , time : Maybe Duration
    , best : Maybe Duration
    , sectors : SectorTimes
    , elapsed : Instant
    , pitTime : Maybe Duration
    , miniSectors : Maybe MiniSectors
    }


{-| How long one sector of this lap took, next to the driver's best for that
sector up to and including this lap — the baseline a time is rated against.

The two are kept together because nothing reads one without the other. Either
can be missing: a sector the source data left blank has no time, and a driver
who has yet to complete one has no best for it.

-}
type alias SectorTime =
    { time : Maybe Duration
    , personalBest : Maybe Duration
    }


{-| A lap's three sector times.
-}
type alias SectorTimes =
    BySector SectorTime


{-| A lap's fifteen mini-sector times, where the circuit records them.
-}
type alias MiniSectors =
    ByMiniSector MiniSectorTime


{-| How long one mini-sector of this lap took, next to the driver's best for it
-- [`SectorTime`](#SectorTime) at the finer grain, and `Nothing` for the same
two reasons.

`elapsedInLap` is the extra the finer grain needs: how far into the lap this
mini-sector ended, counted from the line. The sectors get by without it because
[`segments`](#segments) adds their times up, but that only works while every
time is there -- a sector the source data left blank is taken as no time at all
and the ones after it still start where they should, which is a liberty the
sectors can afford at three and the mini-sectors cannot at fifteen. The source
records the running total, so a mini-sector after a blank one is still placed
exactly.

-}
type alias MiniSectorTime =
    { time : Maybe Duration
    , elapsedInLap : Maybe Duration
    , personalBest : Maybe Duration
    }


empty : Lap
empty =
    { carNumber = ""
    , driver = Driver.unknown
    , lap = 0
    , position = Nothing
    , time = Nothing
    , sectors = Sector.initialize (always { time = Nothing, personalBest = Nothing })
    , best = Nothing
    , elapsed = Instant.raceStart
    , pitTime = Nothing
    , miniSectors = Nothing
    }


{-| A time as the source data spells it, where a zero stands for a time that was
not recorded rather than a very quick one.

For the loader to call on the way in, so that the zero stops at the boundary and
a `Lap` never carries one. Sector times arrive spelled as a blank cell and are
`Nothing` before they get here; a lap time is the one the CLI writes out as
`0.000` whether it was recorded or not.

    recorded 95365
    --> Just 95365

    recorded 0
    --> Nothing

-}
recorded : Duration -> Maybe Duration
recorded time =
    if time == 0 then
        Nothing

    else
        Just time


type alias Clock =
    { elapsed : Instant }


{-| Which of two laps is ahead on track, read at a moment of the race.

Every step of it runs backwards from the plain comparison: the car on the higher
lap, in the later sector, in the later mini sector is the one in front.

-}
compareAt : Clock -> Comparator Lap
compareAt clock =
    Compare.concat
        [ Compare.reverse (Compare.by .lap)
        , compareLapsInSameLap clock
        ]


compareLapsInSameLap : Clock -> Comparator Lap
compareLapsInSameLap clock a b =
    let
        ( sector_a, segment_a ) =
            currentSegment clock a

        ( sector_b, segment_b ) =
            currentSegment clock b
    in
    case Compare.reverse Sector.compare sector_a sector_b of
        EQ ->
            compareLapsInSameSector clock a b segment_a segment_b

        order ->
            order


compareLapsInSameSector : Clock -> Lap -> Lap -> Segment -> Segment -> Order
compareLapsInSameSector clock a b segment_a segment_b =
    case ( a.miniSectors, b.miniSectors ) of
        ( Just _, Just _ ) ->
            case ( currentMiniSector clock a, currentMiniSector clock b ) of
                ( Just ms_a, Just ms_b ) ->
                    case Compare.reverse LeMans.compare ms_a ms_b of
                        EQ ->
                            Instant.compare (miniSectorStart ms_a a) (miniSectorStart ms_b b)

                        order ->
                            order

                ( Just _, Nothing ) ->
                    LT

                ( Nothing, Just _ ) ->
                    GT

                ( Nothing, Nothing ) ->
                    compareBySegmentStart segment_a segment_b

        _ ->
            compareBySegmentStart segment_a segment_b


{-| Both cars are in the same sector of the same lap, so whichever entered it
first is ahead.
-}
compareBySegmentStart : Segment -> Segment -> Order
compareBySegmentStart segment_a segment_b =
    Instant.compare segment_a.start segment_b.start


completedLapsAt : Clock -> List { a | elapsed : Instant } -> List { a | elapsed : Instant }
completedLapsAt clock =
    List.filter (\lap -> Instant.compare lap.elapsed clock.elapsed /= GT)


imcompletedLapsAt : Clock -> List { a | elapsed : Instant } -> List { a | elapsed : Instant }
imcompletedLapsAt clock laps =
    let
        incompletedLaps =
            List.filter (\lap -> Instant.compare lap.elapsed clock.elapsed == GT) laps
    in
    case incompletedLaps of
        [] ->
            List.filterMap identity [ List.Extra.last laps ]

        _ ->
            incompletedLaps


findLastLapAt : Clock -> List { a | elapsed : Instant } -> Maybe { a | elapsed : Instant }
findLastLapAt clock =
    completedLapsAt clock >> List.Extra.last


findCurrentLap : Clock -> List { a | elapsed : Instant } -> Maybe { a | elapsed : Instant }
findCurrentLap clock =
    imcompletedLapsAt clock >> List.head



-- SECTOR


{-| One sector of one lap, as the stretch of race time the car spends in it.

`start` is on the same scale as `Lap.elapsed` and the race clock, so it can be
compared against either without conversion.

Which sector it is belongs to the position in a
[`BySector`](Motorsport-Sector#BySector), not to the value.

-}
type alias Segment =
    { start : Instant
    , time : Duration
    }


{-| When the lap began.

Read off the lap's own end and duration, never the previous lap's, which may be
missing or not adjacent. A lap the source data has no time for has no length, so
it begins where it ends -- which is what the geometry below wants for a lap it
cannot place.

-}
lapStart : Lap -> Instant
lapStart lap =
    Instant.subtract (Maybe.withDefault 0 lap.time) lap.elapsed


{-| Cut a lap into its three sectors.

The lap stores only how long each sector took, so where one begins has to be
added up; this is the only place that happens. A sector with no recorded time is
empty rather than absent, so the two after it still start where they should.

-}
segments : Lap -> BySector Segment
segments lap =
    let
        start =
            lapStart lap

        took sector =
            Maybe.withDefault 0 sector.time

        ( s1, s2, s3 ) =
            ( took lap.sectors.s1, took lap.sectors.s2, took lap.sectors.s3 )
    in
    { s1 = { start = start, time = s1 }
    , s2 = { start = Instant.add s1 start, time = s2 }
    , s3 = { start = Instant.add (s1 + s2) start, time = s3 }
    }


{-| Whether a moment of race time falls inside a segment. Half-open: the
instant a sector ends belongs to the next one.
-}
contains : Instant -> Segment -> Bool
contains raceElapsed segment =
    (Instant.compare raceElapsed segment.start /= LT)
        && (Instant.compare raceElapsed (Instant.add segment.time segment.start) == LT)


{-| The segment the car is driving at the given moment. Moments outside the lap
fall through to the final sector, which is what callers want for a lap that is
already over.
-}
currentSegment : Clock -> Lap -> ( Sector, Segment )
currentSegment clock lap =
    let
        lapSegments =
            segments lap
    in
    lapSegments
        |> Sector.toList
        |> List.Extra.find (\( _, segment ) -> contains clock.elapsed segment)
        |> Maybe.withDefault ( S3, lapSegments.s3 )


currentSector : Clock -> Lap -> Sector
currentSector clock lap =
    Tuple.first (currentSegment clock lap)


{-| How far around the lap the car is: which sector, and how far through it as
a fraction of that sector.

Not clamped: past the end of the lap gives more than 1, before its start gives
a negative, and a sector with no recorded time gives infinity or NaN. Capping
is a question about what is being drawn, so it is left to the caller.

-}
type alias SectorProgress =
    { sector : Sector
    , progress : Float
    }


progressAt : Clock -> Lap -> SectorProgress
progressAt clock lap =
    let
        ( sector, segment ) =
            currentSegment clock lap
    in
    { sector = sector
    , progress = progressThrough clock segment
    }


{-| How far through a segment a moment of race time is, as a fraction of it.

Bounded only by the segment it is given: for one the clock actually falls
inside it is between 0 and 1, and for any other it is whatever the arithmetic
says. Which of those a caller gets is the caller's to know -- see
[`progressAt`](#progressAt) and
[`miniSectorProgressAt`](#miniSectorProgressAt), which differ in exactly that.

-}
progressThrough : Clock -> Segment -> Float
progressThrough clock segment =
    toFloat (Instant.since { from = segment.start, to = clock.elapsed }) / toFloat segment.time


{-| When a given sector of a given lap began — for asking about a sector the
car is not in, or a lap it is not on.
-}
sectorStart : Sector -> Lap -> Instant
sectorStart sector lap =
    (Sector.get sector (segments lap)).start


{-| Cut a lap into the mini-sectors the source data can place, in track order.

The counterpart of [`segments`](#segments), and read the same way after this --
but built from the running totals the source records rather than by adding the
times up. That is the difference the finer grain needs: `segments` treats a
sector it has no time for as taking none at all, so the ones after it still
start where they should, and three sectors can afford that where fifteen
mini-sectors cannot.

The price is that a mini-sector whose running total is missing cannot be
placed, and neither can the one after it, whose start that total is. Such a
mini-sector is absent from the list rather than present and unplaceable -- a
caller looking for where the car is has nothing to do with one either way. A
lap from a circuit that records no mini-sectors gives the empty list for the
same reason.

The first mini-sector begins at the line, which is the `Just 0` the fold
starts from.

-}
miniSegments : Lap -> List ( LeMans2025MiniSector, Segment )
miniSegments lap =
    case lap.miniSectors of
        Nothing ->
            []

        Just miniSectors ->
            let
                start =
                    lapStart lap

                step mini ( placed, previousEnd ) =
                    let
                        end =
                            (LeMans.get mini miniSectors).elapsedInLap
                    in
                    ( case ( previousEnd, end ) of
                        ( Just from, Just to ) ->
                            ( mini, { start = Instant.add from start, time = to - from } ) :: placed

                        _ ->
                            placed
                    , end
                    )
            in
            List.foldl step ( [], Just 0 ) LeMans.all
                |> Tuple.first
                |> List.reverse


{-| The mini-sector the car is driving at the given moment, and the stretch of
race time it is.

Unlike [`currentSegment`](#currentSegment) there is no falling through to the
last one: a clock past the end of the lap is in no mini-sector, and so is a
clock anywhere the source data could not place.

-}
currentMiniSegment : Clock -> Lap -> Maybe ( LeMans2025MiniSector, Segment )
currentMiniSegment clock lap =
    miniSegments lap
        |> List.Extra.find (\( _, segment ) -> contains clock.elapsed segment)


currentMiniSector : Clock -> Lap -> Maybe LeMans2025MiniSector
currentMiniSector clock lap =
    currentMiniSegment clock lap |> Maybe.map Tuple.first


{-| The mini-sector counterpart of [`SectorProgress`](#SectorProgress).

Where a `SectorProgress` can read past the end of its sector, this one cannot:
there is only a mini-sector here because the clock falls inside it, so the
progress is between 0 and 1 by construction rather than by clamping.

-}
type alias MiniSectorProgress =
    { miniSector : LeMans2025MiniSector
    , progress : Float
    }


miniSectorProgressAt : Clock -> Lap -> Maybe MiniSectorProgress
miniSectorProgressAt clock lap =
    currentMiniSegment clock lap
        |> Maybe.map
            (\( miniSector, segment ) ->
                { miniSector = miniSector
                , progress = progressThrough clock segment
                }
            )


{-| When a given mini-sector of a given lap began, the counterpart of
[`sectorStart`](#sectorStart).

A mini-sector the source data cannot place begins where the lap does, which is
what the running-order tie-break wants: two cars it cannot tell apart are left
to whatever the comparison behind it says.

-}
miniSectorStart : LeMans2025MiniSector -> Lap -> Instant
miniSectorStart mini lap =
    miniSegments lap
        |> List.Extra.find (\( candidate, _ ) -> candidate == mini)
        |> Maybe.map (Tuple.second >> .start)
        |> Maybe.withDefault (lapStart lap)
