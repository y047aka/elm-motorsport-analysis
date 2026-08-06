module Motorsport.Lap exposing
    ( Lap, empty
    , SectorTime, SectorTimes
    , MiniSectors, MiniSectorTime
    , recorded
    , compareAt
    , completedLapsAt, findLastLapAt, findCurrentLap
    , Segment, segments, sectorStart
    , SectorProgress, progressAt, currentSector
    , MiniSectorProgress, currentMiniSector, miniSectorProgressAt
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
@docs MiniSectorProgress, currentMiniSector, miniSectorProgressAt

-}

import Compare exposing (Comparator)
import List.Extra
import Motorsport.Circuit.LeMans as LeMans exposing (ByMiniSector, LeMans2025MiniSector(..))
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
                            Instant.compare (miniSectorToElapsed a ms_a) (miniSectorToElapsed b ms_b)

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
    , progress = toFloat (Instant.since { from = segment.start, to = clock.elapsed }) / toFloat segment.time
    }


{-| When a given sector of a given lap began — for asking about a sector the
car is not in, or a lap it is not on.
-}
sectorStart : Sector -> Lap -> Instant
sectorStart sector lap =
    (Sector.get sector (segments lap)).start


currentMiniSector : Clock -> Lap -> Maybe LeMans2025MiniSector
currentMiniSector clock lap =
    lap.miniSectors
        |> Maybe.andThen
            (\ms ->
                let
                    start_of_lap =
                        lapStart lap

                    inRange start end =
                        case ( start, end ) of
                            ( Just start_, Just end_ ) ->
                                contains clock.elapsed
                                    { start = Instant.add start_ start_of_lap, time = end_ - start_ }

                            _ ->
                                False

                    ( rangesReversed, _ ) =
                        List.foldl
                            (\mini ( acc, previousEnd ) ->
                                let
                                    end_ =
                                        miniSectorElapsed ms mini

                                    range =
                                        ( mini, previousEnd, end_ )
                                in
                                ( range :: acc, end_ )
                            )
                            ( [], Just 0 )
                            LeMans.all

                    miniSectorRanges =
                        List.reverse rangesReversed
                in
                miniSectorRanges
                    |> List.Extra.find (\( _, start, end ) -> inRange start end)
                    |> Maybe.map (\( miniSector, _, _ ) -> miniSector)
            )


{-| The mini-sector counterpart of [`SectorProgress`](#SectorProgress), clamped
to 0..1.
-}
type alias MiniSectorProgress =
    { miniSector : LeMans2025MiniSector
    , progress : Float
    }


miniSectorProgressAt : Clock -> { current : Lap, previous : Lap } -> Maybe MiniSectorProgress
miniSectorProgressAt clock { current, previous } =
    case currentMiniSector clock current of
        Just miniSector ->
            current.miniSectors
                |> Maybe.andThen
                    (\miniSectors ->
                        let
                            maybeStart =
                                miniSectorStartElapsed miniSectors miniSector

                            maybeDuration =
                                miniSectorTime miniSectors miniSector
                        in
                        case ( maybeStart, maybeDuration ) of
                            ( Just start_, Just duration_ ) ->
                                let
                                    elapsedSinceStart =
                                        Instant.since
                                            { from = Instant.add start_ previous.elapsed
                                            , to = clock.elapsed
                                            }

                                    progress =
                                        if duration_ <= 0 then
                                            1

                                        else
                                            toFloat elapsedSinceStart / toFloat duration_
                                in
                                Just
                                    { miniSector = miniSector
                                    , progress = progress |> Basics.max 0 |> Basics.min 1
                                    }

                            _ ->
                                Nothing
                    )

        Nothing ->
            Nothing


miniSectorToElapsed : Lap -> LeMans2025MiniSector -> Instant
miniSectorToElapsed lap miniSector =
    let
        intoTheLap =
            lap.miniSectors
                |> Maybe.andThen (\miniSectors -> miniSectorStartElapsed miniSectors miniSector)
                |> Maybe.withDefault 0
    in
    Instant.add intoTheLap (lapStart lap)


miniSectorElapsed : MiniSectors -> LeMans2025MiniSector -> Maybe Duration
miniSectorElapsed miniSectors mini =
    LeMans.get mini miniSectors |> .elapsedInLap


miniSectorTime : MiniSectors -> LeMans2025MiniSector -> Maybe Duration
miniSectorTime miniSectors mini =
    LeMans.get mini miniSectors |> .time


miniSectorStartElapsed : MiniSectors -> LeMans2025MiniSector -> Maybe Duration
miniSectorStartElapsed miniSectors mini =
    case mini of
        SCL2 ->
            Just 0

        _ ->
            miniSectorPrevious mini
                |> Maybe.andThen (miniSectorElapsed miniSectors)


miniSectorPrevious : LeMans2025MiniSector -> Maybe LeMans2025MiniSector
miniSectorPrevious mini =
    LeMans.all
        |> List.Extra.elemIndex mini
        |> Maybe.andThen
            (\index ->
                if index <= 0 then
                    Nothing

                else
                    List.Extra.getAt (index - 1) LeMans.all
            )
