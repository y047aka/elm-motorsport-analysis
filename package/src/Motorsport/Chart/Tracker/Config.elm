module Motorsport.Chart.Tracker.Config exposing
    ( TrackConfig, SectorConfig
    , standard, leMans24h
    , calcSectorProgress, calcSectorBoundaries
    )

{-|

@docs TrackConfig, SectorConfig
@docs standard, leMans24h
@docs calcSectorProgress, calcSectorBoundaries

-}

import Motorsport.Analysis exposing (Analysis)
import Motorsport.Lap exposing (MiniSector(..), Sector(..))
import Motorsport.RaceControl.ViewModel exposing (ViewModelItem)


type alias TrackConfig =
    { cx : Float
    , cy : Float
    , r : Float
    , sectorConfig : SectorConfig
    }


type SectorConfig
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
    { cx = 500
    , cy = 500
    , r = 450
    , sectorConfig = Sectors sectorRatio
    }


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
    { cx = 500
    , cy = 500
    , r = 450
    , sectorConfig = MiniSectors miniSectorRatio
    }


calcSectorProgress : SectorConfig -> ViewModelItem -> Float
calcSectorProgress sectorConfig car =
    case sectorConfig of
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
    case car.timing.miniSector of
        Just ( SCL2, progress ) ->
            progress * ratio.scl2

        Just ( Z4, progress ) ->
            ratio.scl2 + progress * ratio.z4

        Just ( IP1, progress ) ->
            ratio.scl2 + ratio.z4 + progress * ratio.ip1

        Just ( Z12, progress ) ->
            ratio.scl2 + ratio.z4 + ratio.ip1 + progress * ratio.z12

        Just ( SCLC, progress ) ->
            ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + progress * ratio.sclc

        Just ( A7_1, progress ) ->
            ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + ratio.sclc + progress * ratio.a7_1

        Just ( IP2, progress ) ->
            ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + ratio.sclc + ratio.a7_1 + progress * ratio.ip2

        Just ( A8_1, progress ) ->
            ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + ratio.sclc + ratio.a7_1 + ratio.ip2 + progress * ratio.a8_1

        Just ( SCLB, progress ) ->
            ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + ratio.sclc + ratio.a7_1 + ratio.ip2 + ratio.a8_1 + progress * ratio.sclb

        Just ( PORIN, progress ) ->
            ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + ratio.sclc + ratio.a7_1 + ratio.ip2 + ratio.a8_1 + ratio.sclb + progress * ratio.porin

        Just ( POROUT, progress ) ->
            ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + ratio.sclc + ratio.a7_1 + ratio.ip2 + ratio.a8_1 + ratio.sclb + ratio.porin + progress * ratio.porout

        Just ( PITREF, progress ) ->
            ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + ratio.sclc + ratio.a7_1 + ratio.ip2 + ratio.a8_1 + ratio.sclb + ratio.porin + ratio.porout + progress * ratio.pitref

        Just ( SCL1, progress ) ->
            ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + ratio.sclc + ratio.a7_1 + ratio.ip2 + ratio.a8_1 + ratio.sclb + ratio.porin + ratio.porout + ratio.pitref + progress * ratio.scl1

        Just ( FORDOUT, progress ) ->
            ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + ratio.sclc + ratio.a7_1 + ratio.ip2 + ratio.a8_1 + ratio.sclb + ratio.porin + ratio.porout + ratio.pitref + ratio.scl1 + progress * ratio.fordout

        Just ( FL, progress ) ->
            ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + ratio.sclc + ratio.a7_1 + ratio.ip2 + ratio.a8_1 + ratio.sclb + ratio.porin + ratio.porout + ratio.pitref + ratio.scl1 + ratio.fordout + progress * ratio.fl

        Nothing ->
            -- Fallback to sector-based calculation
            case car.timing.sector of
                Just ( S1, progress ) ->
                    (progress / 100) * (ratio.scl2 + ratio.z4 + ratio.ip1)

                Just ( S2, progress ) ->
                    (ratio.scl2 + ratio.z4 + ratio.ip1) + (progress / 100) * (ratio.z12 + ratio.sclc + ratio.a7_1 + ratio.ip2)

                Just ( S3, progress ) ->
                    (ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + ratio.sclc + ratio.a7_1 + ratio.ip2) + (progress / 100) * (ratio.a8_1 + ratio.sclb + ratio.porin + ratio.porout + ratio.pitref + ratio.scl1 + ratio.fordout + ratio.fl)

                Nothing ->
                    case car.currentLap of
                        Nothing ->
                            0

                        Just currentLap ->
                            min 1.0 (toFloat car.timing.time / toFloat currentLap.time)


calcSectorBoundaries : SectorConfig -> List Float
calcSectorBoundaries sectorConfig =
    case sectorConfig of
        Sectors { s1, s2 } ->
            [ (2 * pi * s1) - (pi / 2)
            , (2 * pi * (s1 + s2)) - (pi / 2)
            ]

        MiniSectors ratio ->
            let
                angleStep =
                    2 * pi

                ratios =
                    [ ratio.scl2
                    , ratio.z4
                    , ratio.ip1
                    , ratio.z12
                    , ratio.sclc
                    , ratio.a7_1
                    , ratio.ip2
                    , ratio.a8_1
                    , ratio.sclb
                    , ratio.porin
                    , ratio.porout
                    , ratio.pitref
                    , ratio.scl1
                    , ratio.fordout

                    -- , miniSectorRatio.fl 別途 startFinishLine を描画するので不要
                    ]
            in
            List.foldl
                (\ratioValue acc ->
                    case acc of
                        [] ->
                            [ ratioValue * angleStep - (pi / 2) ]

                        lastAngle :: _ ->
                            (lastAngle + ratioValue * angleStep) :: acc
                )
                []
                ratios
                |> List.reverse
