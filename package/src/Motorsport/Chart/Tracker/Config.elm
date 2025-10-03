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
import Motorsport.RaceControl.ViewModel exposing (ViewModelItem)


type alias SectorRatios =
    { s1 : Float
    , s2 : Float
    , s3 : Float
    }


type alias MiniSectorShare =
    { mini : MiniSector
    , share : Float
    }


type alias SectorWithMiniSectors =
    { sector : Sector
    , miniSectors : List MiniSectorShare
    }


type TrackConfig
    = Sectors SectorRatios
    | MiniSectors (List SectorWithMiniSectors)


standard : Analysis -> TrackConfig
standard analysis =
    let
        totalFastestTime =
            analysis.sector_1_fastest + analysis.sector_2_fastest + analysis.sector_3_fastest

        sectorRatio =
            if totalFastestTime == 0 then
                { s1 = 1 / 3, s2 = 1 / 3, s3 = 1 / 3 }

            else
                { s1 = toFloat analysis.sector_1_fastest / toFloat totalFastestTime
                , s2 = toFloat analysis.sector_2_fastest / toFloat totalFastestTime
                , s3 = toFloat analysis.sector_3_fastest / toFloat totalFastestTime
                }
    in
    Sectors sectorRatio


leMans24h : Analysis -> TrackConfig
leMans24h analysis =
    let
        totalFastestTime =
            analysis.miniSectorFastest.scl2
                + analysis.miniSectorFastest.z4
                + analysis.miniSectorFastest.ip1
                + analysis.miniSectorFastest.z12
                + analysis.miniSectorFastest.sclc
                + analysis.miniSectorFastest.a7_1
                + analysis.miniSectorFastest.ip2
                + analysis.miniSectorFastest.a8_1
                + analysis.miniSectorFastest.sclb
                + analysis.miniSectorFastest.porin
                + analysis.miniSectorFastest.porout
                + analysis.miniSectorFastest.pitref
                + analysis.miniSectorFastest.scl1
                + analysis.miniSectorFastest.fordout
                + analysis.miniSectorFastest.fl

        miniSectorRatio =
            if totalFastestTime == 0 then
                -- Le Mans circuit layout-based ratios
                { scl2 = 7.5 / 150
                , z4 = 7.5 / 150
                , ip1 = 12 / 150
                , z12 = 24 / 150
                , sclc = 3 / 150
                , a7_1 = 15 / 150
                , ip2 = 13 / 150
                , a8_1 = 5.5 / 150
                , sclb = 26 / 150
                , porin = 12.5 / 150
                , porout = 11 / 150
                , pitref = 6 / 150
                , scl1 = 2 / 150
                , fordout = 3 / 150
                , fl = 2 / 150
                }

            else
                { scl2 = toFloat analysis.miniSectorFastest.scl2 / toFloat totalFastestTime
                , z4 = toFloat analysis.miniSectorFastest.z4 / toFloat totalFastestTime
                , ip1 = toFloat analysis.miniSectorFastest.ip1 / toFloat totalFastestTime
                , z12 = toFloat analysis.miniSectorFastest.z12 / toFloat totalFastestTime
                , sclc = toFloat analysis.miniSectorFastest.sclc / toFloat totalFastestTime
                , a7_1 = toFloat analysis.miniSectorFastest.a7_1 / toFloat totalFastestTime
                , ip2 = toFloat analysis.miniSectorFastest.ip2 / toFloat totalFastestTime
                , a8_1 = toFloat analysis.miniSectorFastest.a8_1 / toFloat totalFastestTime
                , sclb = toFloat analysis.miniSectorFastest.sclb / toFloat totalFastestTime
                , porin = toFloat analysis.miniSectorFastest.porin / toFloat totalFastestTime
                , porout = toFloat analysis.miniSectorFastest.porout / toFloat totalFastestTime
                , pitref = toFloat analysis.miniSectorFastest.pitref / toFloat totalFastestTime
                , scl1 = toFloat analysis.miniSectorFastest.scl1 / toFloat totalFastestTime
                , fordout = toFloat analysis.miniSectorFastest.fordout / toFloat totalFastestTime
                , fl = toFloat analysis.miniSectorFastest.fl / toFloat totalFastestTime
                }

        ratioFor miniSector =
            case miniSector of
                SCL2 ->
                    miniSectorRatio.scl2

                Z4 ->
                    miniSectorRatio.z4

                IP1 ->
                    miniSectorRatio.ip1

                Z12 ->
                    miniSectorRatio.z12

                SCLC ->
                    miniSectorRatio.sclc

                A7_1 ->
                    miniSectorRatio.a7_1

                IP2 ->
                    miniSectorRatio.ip2

                A8_1 ->
                    miniSectorRatio.a8_1

                SCLB ->
                    miniSectorRatio.sclb

                PORIN ->
                    miniSectorRatio.porin

                POROUT ->
                    miniSectorRatio.porout

                PITREF ->
                    miniSectorRatio.pitref

                SCL1 ->
                    miniSectorRatio.scl1

                FORDOUT ->
                    miniSectorRatio.fordout

                FL ->
                    miniSectorRatio.fl

        layout =
            Motorsport.Lap.miniSectorLayout
                |> List.map
                    (\( sector, miniSectors ) ->
                        miniSectors
                            |> List.map (\mini -> ( mini, ratioFor mini ))
                            |> miniSectorGroup sector
                    )
    in
    MiniSectors layout


calcSectorProgress : TrackConfig -> ViewModelItem -> Float
calcSectorProgress config car =
    case config of
        Sectors ratio ->
            calcBasicSectorProgress ratio car

        MiniSectors layout ->
            calcMiniSectorProgress layout car


calcBasicSectorProgress : { s1 : Float, s2 : Float, s3 : Float } -> ViewModelItem -> Float
calcBasicSectorProgress ratio car =
    case car.timing.sector of
        Just ( S1, progress ) ->
            (progress / 100) * ratio.s1

        Just ( S2, progress ) ->
            ratio.s1 + (progress / 100) * ratio.s2

        Just ( S3, progress ) ->
            ratio.s1 + ratio.s2 + (progress / 100) * ratio.s3

        Nothing ->
            case car.currentLap of
                Nothing ->
                    0

                Just currentLap ->
                    min 1.0 (toFloat car.timing.time / toFloat currentLap.time)


calcMiniSectorProgress : List SectorWithMiniSectors -> ViewModelItem -> Float
calcMiniSectorProgress layout car =
    let
        segments =
            miniSectorSegments layout

        sectorTotals =
            miniSectorSectorTotals layout

        fallback =
            calcBasicSectorProgress sectorTotals car
    in
    case car.timing.miniSector of
        Just ( miniSector, progress ) ->
            segments
                |> findMiniSectorSegment miniSector
                |> Maybe.map (\segment -> segment.start + progress * segment.share)
                |> Maybe.withDefault fallback

        Nothing ->
            fallback


calcSectorBoundaries : TrackConfig -> List Float
calcSectorBoundaries config =
    case config of
        Sectors { s1, s2 } ->
            [ s1
            , s1 + s2
            ]

        MiniSectors layout ->
            calcMiniSectorBoundaries layout


type alias MiniSectorSegment =
    { sector : Sector
    , mini : MiniSector
    , start : Float
    , share : Float
    }


miniSectorSegments : List SectorWithMiniSectors -> List MiniSectorSegment
miniSectorSegments layout =
    miniSectorSegmentsHelp layout 0 []
        |> List.reverse


miniSectorSegmentsHelp : List SectorWithMiniSectors -> Float -> List MiniSectorSegment -> List MiniSectorSegment
miniSectorSegmentsHelp layout total acc =
    case layout of
        [] ->
            acc

        sectorWithMini :: rest ->
            let
                ( updatedAcc, nextTotal ) =
                    addMiniSectors sectorWithMini.sector sectorWithMini.miniSectors total acc
            in
            miniSectorSegmentsHelp rest nextTotal updatedAcc


addMiniSectors : Sector -> List MiniSectorShare -> Float -> List MiniSectorSegment -> ( List MiniSectorSegment, Float )
addMiniSectors sector minis total acc =
    case minis of
        [] ->
            ( acc, total )

        miniShare :: rest ->
            let
                segment =
                    { sector = sector
                    , mini = miniShare.mini
                    , start = total
                    , share = miniShare.share
                    }

                nextTotal =
                    total + miniShare.share
            in
            addMiniSectors sector rest nextTotal (segment :: acc)


findMiniSectorSegment : MiniSector -> List MiniSectorSegment -> Maybe MiniSectorSegment
findMiniSectorSegment mini segments =
    case segments of
        [] ->
            Nothing

        segment :: rest ->
            if segment.mini == mini then
                Just segment

            else
                findMiniSectorSegment mini rest


miniSectorSectorTotals : List SectorWithMiniSectors -> SectorRatios
miniSectorSectorTotals layout =
    let
        addSector sectorWithMini totals =
            let
                share =
                    sumMiniSectorShares sectorWithMini.miniSectors
            in
            case sectorWithMini.sector of
                S1 ->
                    { totals | s1 = totals.s1 + share }

                S2 ->
                    { totals | s2 = totals.s2 + share }

                S3 ->
                    { totals | s3 = totals.s3 + share }
    in
    List.foldl addSector { s1 = 0, s2 = 0, s3 = 0 } layout


sumMiniSectorShares : List MiniSectorShare -> Float
sumMiniSectorShares minis =
    List.foldl (\miniShare acc -> acc + miniShare.share) 0 minis


calcMiniSectorBoundaries : List SectorWithMiniSectors -> List Float
calcMiniSectorBoundaries layout =
    calcMiniSectorBoundariesHelp layout 0 []
        |> List.reverse


calcMiniSectorBoundariesHelp : List SectorWithMiniSectors -> Float -> List Float -> List Float
calcMiniSectorBoundariesHelp layout total acc =
    case layout of
        [] ->
            acc

        sectorWithMini :: rest ->
            let
                sectorShare =
                    sumMiniSectorShares sectorWithMini.miniSectors

                newTotal =
                    total + sectorShare

                updatedAcc =
                    case rest of
                        [] ->
                            acc

                        _ ->
                            newTotal :: acc
            in
            calcMiniSectorBoundariesHelp rest newTotal updatedAcc


miniSectorGroup : Sector -> List ( MiniSector, Float ) -> SectorWithMiniSectors
miniSectorGroup sector miniPairs =
    { sector = sector
    , miniSectors =
        miniPairs
            |> List.map (\( mini, share ) -> { mini = mini, share = share })
    }
