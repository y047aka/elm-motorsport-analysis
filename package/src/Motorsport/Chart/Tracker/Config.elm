module Motorsport.Chart.Tracker.Config exposing
    ( TrackConfig
    , buildConfig
    , calcSectorProgress, calcSectorBoundaries
    )

{-|

@docs TrackConfig
@docs buildConfig
@docs calcSectorProgress, calcSectorBoundaries

-}

import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Circuit as Circuit exposing (Layout)
import Motorsport.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector)
import Motorsport.RaceControl.ViewModel exposing (ViewModelItem)
import Motorsport.Sector exposing (Sector(..))


type alias TrackConfig =
    { s1 : SectorConfig
    , s2 : SectorConfig
    , s3 : SectorConfig
    }


type alias SectorConfig =
    { share : Float
    , miniSectors : List MiniSectorShare
    }


type alias MiniSectorShare =
    { mini : LeMans2025MiniSector
    , share : Float
    }


buildConfig : Layout LeMans2025MiniSector -> Analysis -> TrackConfig
buildConfig layout analysis =
    let
        isLeMans2025 =
            Circuit.hasMiniSectors layout

        totalTime =
            if isLeMans2025 then
                LeMans.miniSectorOrder
                    |> List.map (\mini -> LeMans.miniSectorAccessor mini analysis.miniSectorFastest)
                    |> List.sum
                    |> toFloat

            else
                toFloat (analysis.sector_1_fastest + analysis.sector_2_fastest + analysis.sector_3_fastest)

        miniRatio miniSector =
            let
                value =
                    LeMans.miniSectorAccessor miniSector analysis.miniSectorFastest
                        |> toFloat

                defaultRatio =
                    LeMans.miniSectorDefaultRatio miniSector
                        |> Maybe.withDefault 0
            in
            if totalTime == 0 then
                defaultRatio

            else
                value / totalTime

        sectorConfig fastestTime miniSectors =
            let
                miniShares =
                    miniSectors
                        |> List.map (\mini -> { mini = mini, share = miniRatio mini })

                share =
                    if List.isEmpty miniSectors then
                        let
                            value =
                                toFloat fastestTime
                        in
                        if totalTime == 0 then
                            Circuit.sectorDefaultRatio

                        else
                            value / totalTime

                    else
                        miniShares
                            |> List.map .share
                            |> List.sum
            in
            { share = share, miniSectors = miniShares }
    in
    { s1 = sectorConfig analysis.sector_1_fastest layout.s1
    , s2 = sectorConfig analysis.sector_2_fastest layout.s2
    , s3 = sectorConfig analysis.sector_3_fastest layout.s3
    }


calcSectorProgress : TrackConfig -> ViewModelItem -> Float
calcSectorProgress config car =
    let
        fallback =
            calcBasicSectorProgress config car
    in
    calcMiniSectorProgress config car fallback


calcBasicSectorProgress : TrackConfig -> ViewModelItem -> Float
calcBasicSectorProgress config car =
    case car.timing.sector of
        Just ( sector, progressPercent ) ->
            let
                ( start, share ) =
                    case sector of
                        S1 ->
                            ( 0, config.s1.share )

                        S2 ->
                            ( config.s1.share, config.s2.share )

                        S3 ->
                            ( config.s1.share + config.s2.share, config.s3.share )
            in
            start + (progressPercent / 100) * share

        Nothing ->
            progressFromElapsed car


calcMiniSectorProgress : TrackConfig -> ViewModelItem -> Float -> Float
calcMiniSectorProgress config car fallback =
    case car.timing.miniSector of
        Just ( miniSector, progress ) ->
            findMiniSectorSegment config miniSector
                |> Maybe.map (\segment -> segment.start + progress * segment.share)
                |> Maybe.withDefault fallback

        Nothing ->
            fallback


progressFromElapsed : ViewModelItem -> Float
progressFromElapsed car =
    case car.currentLap of
        Nothing ->
            0

        Just currentLap ->
            min 1.0 (toFloat car.timing.time / toFloat currentLap.time)


calcSectorBoundaries : TrackConfig -> List Float
calcSectorBoundaries config =
    let
        ( _, boundariesRev ) =
            [ config.s1, config.s2, config.s3 ]
                |> List.foldl accumulateBoundaries ( 0, [] )
    in
    boundariesRev
        |> List.filter (\boundary -> boundary > 0 && boundary < 1)
        |> List.reverse


type alias MiniSectorSegment =
    { mini : LeMans2025MiniSector
    , start : Float
    , share : Float
    }


findMiniSectorSegment : TrackConfig -> LeMans2025MiniSector -> Maybe MiniSectorSegment
findMiniSectorSegment config targetMini =
    [ ( config.s1, 0 )
    , ( config.s2, config.s1.share )
    , ( config.s3, config.s1.share + config.s2.share )
    ]
        |> List.Extra.findMap
            (\( sectorConfig, start ) ->
                findMiniInSector targetMini sectorConfig start
                    |> Tuple.first
            )


findMiniInSector : LeMans2025MiniSector -> SectorConfig -> Float -> ( Maybe MiniSectorSegment, Float )
findMiniInSector targetMini sectorConfig start =
    sectorConfig.miniSectors
        |> List.foldl
            (\miniShare ( result, current ) ->
                let
                    segment =
                        { mini = miniShare.mini
                        , start = current
                        , share = miniShare.share
                        }

                    next =
                        current + miniShare.share
                in
                case result of
                    Just _ ->
                        ( result, next )

                    Nothing ->
                        if miniShare.mini == targetMini then
                            ( Just segment, next )

                        else
                            ( Nothing, next )
            )
            ( Nothing, start )


accumulateBoundaries : SectorConfig -> ( Float, List Float ) -> ( Float, List Float )
accumulateBoundaries sectorConfig ( currentStart, acc ) =
    case sectorConfig.miniSectors of
        [] ->
            let
                end =
                    currentStart + sectorConfig.share

                updatedAcc =
                    if sectorConfig.share <= 0 then
                        acc

                    else
                        end :: acc
            in
            ( end, updatedAcc )

        minis ->
            minis
                |> List.foldl
                    (\miniShare ( runningTotal, accInner ) ->
                        let
                            nextTotal =
                                runningTotal + miniShare.share

                            updatedAcc =
                                if miniShare.share <= 0 then
                                    accInner

                                else
                                    nextTotal :: accInner
                        in
                        ( nextTotal, updatedAcc )
                    )
                    ( currentStart, acc )
