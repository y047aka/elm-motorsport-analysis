module Motorsport.Chart.Tracker.Config exposing
    ( TrackConfig
    , standard, leMans24h
    , calcSectorProgress, calcSectorBoundaries
    )

{-|

@docs TrackConfig
@docs standard, leMans24h
@docs calcSectorProgress, calcSectorBoundaries

-}

import Motorsport.Analysis exposing (Analysis)
import Motorsport.Lap exposing (MiniSector(..), Sector(..))
import Motorsport.Lap.Performance exposing (MiniSectorFastest)
import Motorsport.RaceControl.ViewModel exposing (ViewModelItem)


type alias MiniSectorShare =
    { mini : MiniSector
    , share : Float
    }


type alias SectorConfig =
    { sector : Sector
    , share : Float
    , miniSectors : List MiniSectorShare
    }


type alias TrackConfig =
    { s1 : SectorConfig
    , s2 : SectorConfig
    , s3 : SectorConfig
    }


type alias MiniSectorSpec =
    { mini : MiniSector
    , defaultUnits : Float
    , getFastest : MiniSectorFastest -> Float
    }


leMansMiniSectorSpecs : List MiniSectorSpec
leMansMiniSectorSpecs =
    let
        spec mini units accessor =
            { mini = mini
            , defaultUnits = units
            , getFastest = accessor >> toFloat
            }
    in
    [ spec SCL2 7.5 .scl2
    , spec Z4 7.5 .z4
    , spec IP1 12 .ip1
    , spec Z12 24 .z12
    , spec SCLC 3 .sclc
    , spec A7_1 15 .a7_1
    , spec IP2 13 .ip2
    , spec A8_1 5.5 .a8_1
    , spec SCLB 26 .sclb
    , spec PORIN 12.5 .porin
    , spec POROUT 11 .porout
    , spec PITREF 6 .pitref
    , spec SCL1 2 .scl1
    , spec FORDOUT 3 .fordout
    , spec FL 2 .fl
    ]


leMansDefaultUnits : Float
leMansDefaultUnits =
    leMansMiniSectorSpecs
        |> List.foldl (\spec acc -> acc + spec.defaultUnits) 0


leMansSpecFor : MiniSector -> MiniSectorSpec
leMansSpecFor mini =
    leMansMiniSectorSpecs
        |> List.foldl
            (\spec acc ->
                case acc of
                    Just _ ->
                        acc

                    Nothing ->
                        if spec.mini == mini then
                            Just spec

                        else
                            Nothing
            )
            Nothing
        |> Maybe.withDefault
            { mini = mini
            , defaultUnits = 0
            , getFastest = \_ -> 0
            }


standard : Analysis -> TrackConfig
standard analysis =
    let
        totalFastestTime =
            analysis.sector_1_fastest + analysis.sector_2_fastest + analysis.sector_3_fastest

        ratio value =
            if totalFastestTime == 0 then
                1 / 3

            else
                toFloat value / toFloat totalFastestTime

        emptySector sector share =
            { sector = sector
            , share = share
            , miniSectors = []
            }
    in
    { s1 = emptySector S1 (ratio analysis.sector_1_fastest)
    , s2 = emptySector S2 (ratio analysis.sector_2_fastest)
    , s3 = emptySector S3 (ratio analysis.sector_3_fastest)
    }


leMans24h : Analysis -> TrackConfig
leMans24h analysis =
    let
        totalFastestTime =
            leMansMiniSectorSpecs
                |> List.foldl (\spec acc -> acc + spec.getFastest analysis.miniSectorFastest) 0

        ratioFor miniSector =
            let
                spec =
                    leMansSpecFor miniSector
            in
            if totalFastestTime == 0 then
                spec.defaultUnits / leMansDefaultUnits

            else
                spec.getFastest analysis.miniSectorFastest / totalFastestTime

        sectorConfig ( sector, miniSectors ) =
            let
                miniShares =
                    miniSectors
                        |> List.map (\mini -> { mini = mini, share = ratioFor mini })

                share =
                    sumMiniSectorShares miniShares
            in
            { sector = sector
            , share = share
            , miniSectors = miniShares
            }

        sectors =
            Motorsport.Lap.miniSectorLayout
                |> List.map sectorConfig

        lookup targetSector default =
            sectors
                |> List.filter (\sectorConfig_ -> sectorConfig_.sector == targetSector)
                |> List.head
                |> Maybe.withDefault default

        defaultSector targetSector =
            { sector = targetSector
            , share = 1 / 3
            , miniSectors = []
            }
    in
    { s1 = lookup S1 (defaultSector S1)
    , s2 = lookup S2 (defaultSector S2)
    , s3 = lookup S3 (defaultSector S3)
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
                start =
                    sectorStart config sector

                share =
                    sectorShare config sector
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
    { sector : Sector
    , mini : MiniSector
    , start : Float
    , share : Float
    }


findMiniSectorSegment : TrackConfig -> MiniSector -> Maybe MiniSectorSegment
findMiniSectorSegment config targetMini =
    [ config.s1, config.s2, config.s3 ]
        |> List.foldl
            (\sectorConfig ( result, total ) ->
                case result of
                    Just segment ->
                        ( Just segment, total + sectorConfig.share )

                    Nothing ->
                        let
                            ( found, nextTotal ) =
                                findMiniInSector targetMini sectorConfig total

                            resolvedTotal =
                                if List.isEmpty sectorConfig.miniSectors then
                                    total + sectorConfig.share

                                else
                                    nextTotal
                        in
                        ( found, resolvedTotal )
            )
            ( Nothing, 0 )
        |> Tuple.first


findMiniInSector : MiniSector -> SectorConfig -> Float -> ( Maybe MiniSectorSegment, Float )
findMiniInSector targetMini sectorConfig start =
    sectorConfig.miniSectors
        |> List.foldl
            (\miniShare ( result, current ) ->
                let
                    segment =
                        { sector = sectorConfig.sector
                        , mini = miniShare.mini
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


sectorShare : TrackConfig -> Sector -> Float
sectorShare config sector =
    case sector of
        S1 ->
            config.s1.share

        S2 ->
            config.s2.share

        S3 ->
            config.s3.share


sectorStart : TrackConfig -> Sector -> Float
sectorStart config sector =
    case sector of
        S1 ->
            0

        S2 ->
            config.s1.share

        S3 ->
            config.s1.share + config.s2.share


sumMiniSectorShares : List MiniSectorShare -> Float
sumMiniSectorShares minis =
    List.foldl (\miniShare acc -> acc + miniShare.share) 0 minis
