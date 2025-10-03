module Motorsport.Lap exposing
    ( Lap, empty
    , compareAt
    , completedLapsAt, findLastLapAt, findCurrentLap
    , currentSector
    , currentMiniSector, miniSectorProgressAt
    , sectorToElapsed
    )

{-|

@docs Lap, empty
@docs compareAt
@docs completedLapsAt, findLastLapAt, findCurrentLap

@docs currentSector
@docs currentMiniSector, miniSectorProgressAt

-}

import List.Extra
import Motorsport.Circuit as Circuit
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Sector as Sector exposing (MiniSector(..), Sector(..))


type alias Lap =
    { carNumber : String
    , driver : Driver
    , lap : Int
    , position : Maybe Int
    , time : Duration
    , best : Duration
    , sector_1 : Duration
    , sector_2 : Duration
    , sector_3 : Duration
    , s1_best : Duration
    , s2_best : Duration
    , s3_best : Duration
    , elapsed : Duration
    , miniSectors : Maybe MiniSectors
    }


type alias MiniSectors =
    { scl2 : MiniSectorData
    , z4 : MiniSectorData
    , ip1 : MiniSectorData
    , z12 : MiniSectorData
    , sclc : MiniSectorData
    , a7_1 : MiniSectorData
    , ip2 : MiniSectorData
    , a8_1 : MiniSectorData
    , sclb : MiniSectorData
    , porin : MiniSectorData
    , porout : MiniSectorData
    , pitref : MiniSectorData
    , scl1 : MiniSectorData
    , fordout : MiniSectorData
    , fl : MiniSectorData
    }


type alias MiniSectorData =
    { time : Maybe Duration
    , elapsed : Maybe Duration
    , best : Maybe Duration
    }


empty : Lap
empty =
    { carNumber = ""
    , driver = Driver ""
    , lap = 0
    , position = Nothing
    , time = 0
    , sector_1 = 0
    , sector_2 = 0
    , sector_3 = 0
    , s1_best = 0
    , s2_best = 0
    , s3_best = 0
    , best = 0
    , elapsed = 0
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
        currentSector_a =
            currentSector clock a

        currentSector_b =
            currentSector clock b
    in
    case Basics.compare (Sector.toString currentSector_a) (Sector.toString currentSector_b) of
        LT ->
            GT

        EQ ->
            compareLapsInSameSector clock a b currentSector_a

        GT ->
            LT


compareLapsInSameSector : Clock -> Lap -> Lap -> Sector -> Order
compareLapsInSameSector clock a b currentSector_ =
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
                    compareLapsWithSectorElapsed a b currentSector_

        _ ->
            compareLapsWithSectorElapsed a b currentSector_


compareLapsWithSectorElapsed : Lap -> Lap -> Sector -> Order
compareLapsWithSectorElapsed a b currentSector_ =
    Basics.compare (sectorToElapsed a currentSector_) (sectorToElapsed b currentSector_)


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


currentSector : Clock -> Lap -> Sector
currentSector clock lap =
    let
        elapsed_lastLap =
            lap.elapsed - lap.time
    in
    if clock.elapsed >= elapsed_lastLap && clock.elapsed < (elapsed_lastLap + lap.sector_1) then
        S1

    else if clock.elapsed >= (elapsed_lastLap + lap.sector_1) && clock.elapsed < (elapsed_lastLap + lap.sector_1 + lap.sector_2) then
        S2

    else
        S3


sectorToElapsed : Lap -> Sector -> Duration
sectorToElapsed lap sector =
    let
        elapsed_lastLap =
            lap.elapsed - lap.time
    in
    case sector of
        S1 ->
            elapsed_lastLap

        S2 ->
            elapsed_lastLap + lap.sector_1

        S3 ->
            elapsed_lastLap + lap.sector_1 + lap.sector_2


miniSectorOrder : List MiniSector
miniSectorOrder =
    Circuit.leMans2025
        |> List.concatMap (\( _, minis ) -> minis)


currentMiniSector : Clock -> Lap -> Maybe MiniSector
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


miniSectorProgressAt : Clock -> ( Lap, Lap ) -> Maybe ( MiniSector, Float )
miniSectorProgressAt clock ( currentLap, lastLap ) =
    case currentMiniSector clock currentLap of
        Just miniSector ->
            currentLap.miniSectors
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
                                        clock.elapsed - (lastLap.elapsed + start_)

                                    progress =
                                        if duration_ <= 0 then
                                            1

                                        else
                                            toFloat elapsedSinceStart / toFloat duration_

                                    clamped =
                                        progress
                                            |> Basics.max 0
                                            |> Basics.min 1
                                in
                                Just ( miniSector, clamped )

                            _ ->
                                Nothing
                    )

        Nothing ->
            Nothing


miniSectorToIndex : MiniSector -> Int
miniSectorToIndex miniSector =
    miniSectorOrder
        |> List.Extra.elemIndex miniSector
        |> Maybe.withDefault 0


miniSectorToElapsed : Lap -> MiniSector -> Duration
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


miniSectorData : MiniSectors -> MiniSector -> MiniSectorData
miniSectorData miniSectors mini =
    case mini of
        SCL2 ->
            miniSectors.scl2

        Z4 ->
            miniSectors.z4

        IP1 ->
            miniSectors.ip1

        Z12 ->
            miniSectors.z12

        SCLC ->
            miniSectors.sclc

        A7_1 ->
            miniSectors.a7_1

        IP2 ->
            miniSectors.ip2

        A8_1 ->
            miniSectors.a8_1

        SCLB ->
            miniSectors.sclb

        PORIN ->
            miniSectors.porin

        POROUT ->
            miniSectors.porout

        PITREF ->
            miniSectors.pitref

        SCL1 ->
            miniSectors.scl1

        FORDOUT ->
            miniSectors.fordout

        FL ->
            miniSectors.fl


miniSectorElapsed : MiniSectors -> MiniSector -> Maybe Duration
miniSectorElapsed miniSectors mini =
    miniSectorData miniSectors mini |> .elapsed


miniSectorTime : MiniSectors -> MiniSector -> Maybe Duration
miniSectorTime miniSectors mini =
    miniSectorData miniSectors mini |> .time


miniSectorStartElapsed : MiniSectors -> MiniSector -> Maybe Duration
miniSectorStartElapsed miniSectors mini =
    case mini of
        SCL2 ->
            Just 0

        _ ->
            miniSectorPrevious mini
                |> Maybe.andThen (miniSectorElapsed miniSectors)


miniSectorPrevious : MiniSector -> Maybe MiniSector
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
