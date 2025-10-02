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


type TrackConfig
    = Sectors
        { s1 : Float
        , s2 : Float
        , s3 : Float
        }
    | MiniSectors
        { scl2 : Float
        , z4 : Float
        , ip1 : Float
        , z12 : Float
        , sclc : Float
        , a7_1 : Float
        , ip2 : Float
        , a8_1 : Float
        , sclb : Float
        , porin : Float
        , porout : Float
        , pitref : Float
        , scl1 : Float
        , fordout : Float
        , fl : Float
        }


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
    in
    MiniSectors miniSectorRatio


calcSectorProgress : TrackConfig -> ViewModelItem -> Float
calcSectorProgress config car =
    case config of
        Sectors ratio ->
            calcBasicSectorProgress ratio car

        MiniSectors ratio ->
            calcMiniSectorProgress ratio car


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


calcMiniSectorProgress : { scl2 : Float, z4 : Float, ip1 : Float, z12 : Float, sclc : Float, a7_1 : Float, ip2 : Float, a8_1 : Float, sclb : Float, porin : Float, porout : Float, pitref : Float, scl1 : Float, fordout : Float, fl : Float } -> ViewModelItem -> Float
calcMiniSectorProgress ratio car =
    let
        segments =
            miniSectorSegments ratio

        sectorTotals =
            miniSectorSectorTotals segments

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

        MiniSectors ratio ->
            miniSectorSegments ratio
                -- flは別途 startFinishLine を描画するので不要
                |> List.filter (\segment -> segment.mini /= FL)
                |> List.map (\segment -> segment.start + segment.share)


type alias MiniSectorSegment =
    { mini : MiniSector
    , start : Float
    , share : Float
    }


miniSectorSegments :
    { scl2 : Float
    , z4 : Float
    , ip1 : Float
    , z12 : Float
    , sclc : Float
    , a7_1 : Float
    , ip2 : Float
    , a8_1 : Float
    , sclb : Float
    , porin : Float
    , porout : Float
    , pitref : Float
    , scl1 : Float
    , fordout : Float
    , fl : Float
    }
    -> List MiniSectorSegment
miniSectorSegments ratio =
    let
        ( segments, _ ) =
            miniSectorRatios ratio
                |> List.foldl
                    (\( mini, share ) ( acc, total ) ->
                        ( { mini = mini, start = total, share = share } :: acc, total + share )
                    )
                    ( [], 0 )
    in
    List.reverse segments


miniSectorRatios :
    { scl2 : Float
    , z4 : Float
    , ip1 : Float
    , z12 : Float
    , sclc : Float
    , a7_1 : Float
    , ip2 : Float
    , a8_1 : Float
    , sclb : Float
    , porin : Float
    , porout : Float
    , pitref : Float
    , scl1 : Float
    , fordout : Float
    , fl : Float
    }
    -> List ( MiniSector, Float )
miniSectorRatios ratio =
    [ ( SCL2, ratio.scl2 )
    , ( Z4, ratio.z4 )
    , ( IP1, ratio.ip1 )
    , ( Z12, ratio.z12 )
    , ( SCLC, ratio.sclc )
    , ( A7_1, ratio.a7_1 )
    , ( IP2, ratio.ip2 )
    , ( A8_1, ratio.a8_1 )
    , ( SCLB, ratio.sclb )
    , ( PORIN, ratio.porin )
    , ( POROUT, ratio.porout )
    , ( PITREF, ratio.pitref )
    , ( SCL1, ratio.scl1 )
    , ( FORDOUT, ratio.fordout )
    , ( FL, ratio.fl )
    ]


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


miniSectorSectorTotals : List MiniSectorSegment -> { s1 : Float, s2 : Float, s3 : Float }
miniSectorSectorTotals segments =
    let
        addShare segment totals =
            case miniSectorToSector segment.mini of
                S1 ->
                    { totals | s1 = totals.s1 + segment.share }

                S2 ->
                    { totals | s2 = totals.s2 + segment.share }

                S3 ->
                    { totals | s3 = totals.s3 + segment.share }
    in
    List.foldl addShare { s1 = 0, s2 = 0, s3 = 0 } segments


miniSectorToSector : MiniSector -> Sector
miniSectorToSector miniSector =
    case miniSector of
        SCL2 ->
            S1

        Z4 ->
            S1

        IP1 ->
            S1

        Z12 ->
            S2

        SCLC ->
            S2

        A7_1 ->
            S2

        IP2 ->
            S2

        A8_1 ->
            S3

        SCLB ->
            S3

        PORIN ->
            S3

        POROUT ->
            S3

        PITREF ->
            S3

        SCL1 ->
            S3

        FORDOUT ->
            S3

        FL ->
            S3
