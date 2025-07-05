module Motorsport.Chart.Tracker_LeMans24h exposing (view)

import Css exposing (maxWidth, pct)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Class as Class
import Motorsport.Lap exposing (MiniSector(..), Sector(..))
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel as ViewModel exposing (ViewModelItem)
import Svg.Styled exposing (Svg, circle, g, line, svg, text, text_)
import Svg.Styled.Attributes exposing (css, dominantBaseline, fill, stroke, textAnchor)
import Svg.Styled.Keyed as Keyed
import Svg.Styled.Lazy as Lazy
import TypedSvg.Styled.Attributes as Attributes exposing (cx, cy, fontSize, height, r, strokeWidth, viewBox, width, x1, x2, y1, y2)
import TypedSvg.Types exposing (px)


type alias TrackConfig =
    { cx : Float
    , cy : Float
    , r : Float
    , miniSectorRatio : MiniSectorRatio
    }


type alias MiniSectorRatio =
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


calcMiniSectorRatio : Analysis -> MiniSectorRatio
calcMiniSectorRatio analysis =
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
    in
    if totalFastestTime == 0 then
        -- Le Mans circuit layout-based ratios (total: 149)
        { scl2 = 7.5 / 150 -- Short corner section
        , z4 = 7.5 / 150 -- Short corner section
        , ip1 = 12 / 150 -- Medium section
        , z12 = 24 / 150 -- Medium section
        , sclc = 3 / 150 -- Medium section
        , a7_1 = 15 / 150 -- Medium section
        , ip2 = 13 / 150 -- Short section
        , a8_1 = 5.5 / 150 -- Short section
        , sclb = 26 / 150 -- Medium section
        , porin = 12.5 / 150 -- Very short pit section
        , porout = 11 / 150 -- Very short pit section
        , pitref = 6 / 150 -- Short pit section
        , scl1 = 2 / 150 -- Long Mulsanne straight section
        , fordout = 3 / 150 -- Long straight section
        , fl = 2 / 150 -- Final section to start/finish
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


view : Analysis -> RaceControl.Model -> Svg msg
view analysis raceControl =
    let
        config =
            { cx = 500
            , cy = 500
            , r = 450
            , miniSectorRatio = calcMiniSectorRatio analysis
            }
    in
    svg
        [ width (px 1000)
        , height (px 1000)
        , viewBox 0 0 1000 1000
        , css [ maxWidth (pct 100) ]
        ]
        [ Lazy.lazy track config
        , renderCars config raceControl
        ]


track : TrackConfig -> Svg msg
track { cx, cy, r, miniSectorRatio } =
    let
        trackCircle =
            circle
                [ Attributes.cx (px cx)
                , Attributes.cy (px cy)
                , Attributes.r (px r)
                , fill "none"
                , stroke "#333"
                , strokeWidth (px 4)
                ]
                []

        startFinishLine =
            line
                [ x1 (px cx)
                , y1 (px (cy - r - 15))
                , x2 (px cx)
                , y2 (px (cy - r + 15))
                , stroke "#fff"
                , strokeWidth (px 4)
                ]
                []

        makeMiniSectorBoundary angle =
            line
                [ x1 (px (cx + (r - 10) * cos angle))
                , y1 (px (cy + (r - 10) * sin angle))
                , x2 (px (cx + (r + 10) * cos angle))
                , y2 (px (cy + (r + 10) * sin angle))
                , stroke "#aaa"
                , strokeWidth (px 2)
                ]
                []

        -- Calculate cumulative angles for each mini sector boundary
        cumulativeAngles =
            let
                angleStep =
                    2 * pi

                ratios =
                    [ miniSectorRatio.scl2
                    , miniSectorRatio.z4
                    , miniSectorRatio.ip1
                    , miniSectorRatio.z12
                    , miniSectorRatio.sclc
                    , miniSectorRatio.a7_1
                    , miniSectorRatio.ip2
                    , miniSectorRatio.a8_1
                    , miniSectorRatio.sclb
                    , miniSectorRatio.porin
                    , miniSectorRatio.porout
                    , miniSectorRatio.pitref
                    , miniSectorRatio.scl1
                    , miniSectorRatio.fordout

                    -- , miniSectorRatio.fl 別途 startFinishLine を描画するので不要
                    ]
            in
            List.foldl
                (\ratio acc ->
                    case acc of
                        [] ->
                            [ ratio * angleStep - (pi / 2) ]

                        lastAngle :: _ ->
                            (lastAngle + ratio * angleStep) :: acc
                )
                []
                ratios
                |> List.reverse

        miniSectorBoundaries =
            List.map makeMiniSectorBoundary cumulativeAngles
    in
    g [] (trackCircle :: startFinishLine :: miniSectorBoundaries)


renderCars : TrackConfig -> RaceControl.Model -> Svg msg
renderCars config raceControl =
    Keyed.node "g"
        []
        (ViewModel.init raceControl
            |> List.reverse
            |> List.map (\car -> ( car.metaData.carNumber, Lazy.lazy2 renderCarOnTrack config car ))
        )


renderCarOnTrack : TrackConfig -> ViewModelItem -> Svg msg
renderCarOnTrack config car =
    coordinatesOnTrack config car
        |> renderCar car


coordinatesOnTrack : TrackConfig -> ViewModelItem -> { x : Float, y : Float }
coordinatesOnTrack { cx, cy, r, miniSectorRatio } car =
    let
        progress =
            calcProgress miniSectorRatio car

        -- Convert progress to angle (0 at 12 o'clock position, clockwise)
        angle =
            2 * pi * progress - (pi / 2)
    in
    { x = cx + r * cos angle
    , y = cy + r * sin angle
    }


renderCar : ViewModelItem -> { x : Float, y : Float } -> Svg msg
renderCar car { x, y } =
    let
        carColor =
            Class.toHexColor 2025 car.metaData.class |> .value

        carCircle =
            circle
                [ Attributes.cx (px x)
                , Attributes.cy (px y)
                , Attributes.r (px 15)
                , fill carColor
                ]
                []

        carNumber =
            text_
                [ Attributes.x (px x)
                , Attributes.y (px y)
                , fontSize (px 15)
                , textAnchor "middle"
                , dominantBaseline "central"
                , fill "#fff"
                ]
                [ text car.metaData.carNumber ]
    in
    g [] [ carCircle, carNumber ]


calcProgress : MiniSectorRatio -> ViewModelItem -> Float
calcProgress ratio car =
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

        -- Fallback to sector-based calculation if mini sector data is not available
        Nothing ->
            case car.timing.sector of
                Just ( S1, progress ) ->
                    -- Map S1 to first few mini sectors
                    (progress / 100) * (ratio.scl2 + ratio.z4 + ratio.ip1)

                Just ( S2, progress ) ->
                    -- Map S2 to middle mini sectors
                    (ratio.scl2 + ratio.z4 + ratio.ip1) + (progress / 100) * (ratio.z12 + ratio.sclc + ratio.a7_1 + ratio.ip2)

                Just ( S3, progress ) ->
                    -- Map S3 to last mini sectors
                    (ratio.scl2 + ratio.z4 + ratio.ip1 + ratio.z12 + ratio.sclc + ratio.a7_1 + ratio.ip2) + (progress / 100) * (ratio.a8_1 + ratio.sclb + ratio.porin + ratio.porout + ratio.pitref + ratio.scl1 + ratio.fordout + ratio.fl)

                Nothing ->
                    case car.currentLap of
                        Nothing ->
                            0

                        Just currentLap ->
                            min 1.0 (toFloat car.timing.time / toFloat currentLap.time)
