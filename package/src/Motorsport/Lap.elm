module Motorsport.Lap exposing
    ( Lap, empty
    , SectorTime, SectorTimes
    , MiniSectors, MiniSectorData
    , compareAt
    , completedLapsAt, findLastLapAt, findCurrentLap
    , Segment, segments, sectorStart
    , SectorProgress, progressAt, currentSector
    , MiniSectorProgress, currentMiniSector, miniSectorProgressAt
    )

{-|

@docs Lap, empty
@docs SectorTime, SectorTimes
@docs MiniSectors, MiniSectorData
@docs compareAt
@docs completedLapsAt, findLastLapAt, findCurrentLap


## Sectors as segments of the lap

@docs Segment, segments, sectorStart


## Where the car is on the lap

@docs SectorProgress, progressAt, currentSector
@docs MiniSectorProgress, currentMiniSector, miniSectorProgressAt

-}

import List.Extra
import Motorsport.Circuit.LeMans as LeMans exposing (ByMiniSector, LeMans2025MiniSector(..))
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Sector as Sector exposing (BySector, Sector(..))


type alias Lap =
    { carNumber : String
    , driver : Driver
    , lap : Int
    , position : Maybe Int
    , time : Duration
    , best : Duration
    , sectors : SectorTimes
    , elapsed : Duration
    , pitTime : Maybe Duration
    , miniSectors : Maybe MiniSectors
    }


{-| How long one sector of this lap took, next to the driver's best for that
sector up to and including this lap — the baseline a time is rated against.

The two are kept together because nothing reads one without the other.

-}
type alias SectorTime =
    { time : Duration
    , personalBest : Duration
    }


{-| A lap's three sector times.
-}
type alias SectorTimes =
    BySector SectorTime


type alias MiniSectors =
    ByMiniSector MiniSectorData


type alias MiniSectorData =
    { time : Maybe Duration
    , elapsed : Maybe Duration
    , best : Maybe Duration
    }


empty : Lap
empty =
    { carNumber = ""
    , driver = Driver.unknown
    , lap = 0
    , position = Nothing
    , time = 0
    , sectors = Sector.initialize (always { time = 0, personalBest = 0 })
    , best = 0
    , elapsed = 0
    , pitTime = Nothing
    , miniSectors = Nothing
    }


type alias Clock =
    { elapsed : Duration }


compareAt : Clock -> Lap -> Lap -> Order
compareAt clock a b =
    case Basics.compare a.lap b.lap of
        LT ->
            GT

        EQ ->
            compareLapsInSameLap clock a b

        GT ->
            LT


compareLapsInSameLap : Clock -> Lap -> Lap -> Order
compareLapsInSameLap clock a b =
    let
        ( sector_a, segment_a ) =
            currentSegment clock a

        ( sector_b, segment_b ) =
            currentSegment clock b
    in
    case Sector.compare sector_a sector_b of
        LT ->
            GT

        EQ ->
            compareLapsInSameSector clock a b segment_a segment_b

        GT ->
            LT


compareLapsInSameSector : Clock -> Lap -> Lap -> Segment -> Segment -> Order
compareLapsInSameSector clock a b segment_a segment_b =
    case ( a.miniSectors, b.miniSectors ) of
        ( Just _, Just _ ) ->
            case ( currentMiniSector clock a, currentMiniSector clock b ) of
                ( Just ms_a, Just ms_b ) ->
                    case Basics.compare (miniSectorToIndex ms_a) (miniSectorToIndex ms_b) of
                        LT ->
                            GT

                        GT ->
                            LT

                        EQ ->
                            Basics.compare (miniSectorToElapsed a ms_a) (miniSectorToElapsed b ms_b)

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
    Basics.compare segment_a.start segment_b.start


completedLapsAt : Clock -> List { a | elapsed : Duration } -> List { a | elapsed : Duration }
completedLapsAt clock =
    List.filter (\lap -> lap.elapsed <= clock.elapsed)


imcompletedLapsAt : Clock -> List { a | elapsed : Duration } -> List { a | elapsed : Duration }
imcompletedLapsAt clock laps =
    let
        incompletedLaps =
            List.filter (\lap -> lap.elapsed > clock.elapsed) laps
    in
    case incompletedLaps of
        [] ->
            List.filterMap identity [ List.Extra.last laps ]

        _ ->
            incompletedLaps


findLastLapAt : Clock -> List { a | elapsed : Duration } -> Maybe { a | elapsed : Duration }
findLastLapAt clock =
    completedLapsAt clock >> List.Extra.last


findCurrentLap : Clock -> List { a | elapsed : Duration } -> Maybe { a | elapsed : Duration }
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
    { start : Duration
    , time : Duration
    }


{-| Cut a lap into its three sectors.

The lap stores only how long each sector took, so where one begins has to be
added up; this is the only place that happens. It adds up from the lap's own
end and duration, never the previous lap's, which may be missing or not
adjacent.

-}
segments : Lap -> BySector Segment
segments lap =
    let
        start =
            lap.elapsed - lap.time
    in
    { s1 = { start = start, time = lap.sectors.s1.time }
    , s2 = { start = start + lap.sectors.s1.time, time = lap.sectors.s2.time }
    , s3 = { start = start + lap.sectors.s1.time + lap.sectors.s2.time, time = lap.sectors.s3.time }
    }


{-| Whether a moment of race time falls inside a segment. Half-open: the
instant a sector ends belongs to the next one.
-}
contains : Duration -> Segment -> Bool
contains raceElapsed segment =
    raceElapsed >= segment.start && raceElapsed < (segment.start + segment.time)


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
    , progress = toFloat (clock.elapsed - segment.start) / toFloat segment.time
    }


{-| When a given sector of a given lap began — for asking about a sector the
car is not in, or a lap it is not on.
-}
sectorStart : Sector -> Lap -> Duration
sectorStart sector lap =
    (Sector.get sector (segments lap)).start


miniSectorOrder : List LeMans2025MiniSector
miniSectorOrder =
    LeMans.miniSectorOrder


currentMiniSector : Clock -> Lap -> Maybe LeMans2025MiniSector
currentMiniSector clock lap =
    lap.miniSectors
        |> Maybe.andThen
            (\ms ->
                let
                    elapsed_lastLap =
                        lap.elapsed - lap.time

                    inRange start end =
                        case ( start, end ) of
                            ( Just start_, Just end_ ) ->
                                clock.elapsed >= (start_ + elapsed_lastLap) && clock.elapsed < (end_ + elapsed_lastLap)

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
                            miniSectorOrder

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
                                        clock.elapsed - (previous.elapsed + start_)

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


miniSectorToIndex : LeMans2025MiniSector -> Int
miniSectorToIndex miniSector =
    miniSectorOrder
        |> List.Extra.elemIndex miniSector
        |> Maybe.withDefault 0


miniSectorToElapsed : Lap -> LeMans2025MiniSector -> Duration
miniSectorToElapsed lap miniSector =
    let
        elapsed_lastLap =
            lap.elapsed - lap.time
    in
    elapsed_lastLap
        + (lap.miniSectors
            |> Maybe.andThen (\miniSectors -> miniSectorStartElapsed miniSectors miniSector)
            |> Maybe.withDefault 0
          )


miniSectorElapsed : MiniSectors -> LeMans2025MiniSector -> Maybe Duration
miniSectorElapsed miniSectors mini =
    LeMans.get mini miniSectors |> .elapsed


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
    miniSectorOrder
        |> List.Extra.elemIndex mini
        |> Maybe.andThen
            (\index ->
                if index <= 0 then
                    Nothing

                else
                    List.Extra.getAt (index - 1) miniSectorOrder
            )
