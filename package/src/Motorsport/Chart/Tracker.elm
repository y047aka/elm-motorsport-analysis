module Motorsport.Chart.Tracker exposing (view)

import Motorsport.Analysis exposing (Analysis)
import Motorsport.Class as Class
import Motorsport.Lap exposing (Sector(..))
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel as ViewModel exposing (ViewModelItem)
import Svg.Styled exposing (Svg, circle, g, line, svg, text, text_)
import Svg.Styled.Attributes exposing (dominantBaseline, fill, stroke, textAnchor)
import Svg.Styled.Keyed as Keyed
import Svg.Styled.Lazy as Lazy
import TypedSvg.Styled.Attributes as Attributes exposing (cx, cy, fontSize, height, r, strokeWidth, viewBox, width, x1, x2, y1, y2)
import TypedSvg.Types exposing (px)


type alias TrackConfig =
    { cx : Float
    , cy : Float
    , r : Float
    , sectorRatio : { s1 : Float, s2 : Float, s3 : Float }
    }


calcSectorRatio : Analysis -> { s1 : Float, s2 : Float, s3 : Float }
calcSectorRatio analysis =
    let
        totalFastestTime =
            analysis.sector_1_fastest + analysis.sector_2_fastest + analysis.sector_3_fastest
    in
    if totalFastestTime == 0 then
        { s1 = 1 / 3, s2 = 1 / 3, s3 = 1 / 3 }

    else
        { s1 = toFloat analysis.sector_1_fastest / toFloat totalFastestTime
        , s2 = toFloat analysis.sector_2_fastest / toFloat totalFastestTime
        , s3 = toFloat analysis.sector_3_fastest / toFloat totalFastestTime
        }


view : Analysis -> RaceControl.Model -> Svg msg
view analysis raceControl =
    let
        config =
            { cx = 500
            , cy = 500
            , r = 450
            , sectorRatio = calcSectorRatio analysis
            }
    in
    svg
        [ width (px 1000)
        , height (px 1000)
        , viewBox 0 0 1000 1000
        ]
        [ Lazy.lazy track config
        , renderCars config raceControl
        ]


track : TrackConfig -> Svg msg
track { cx, cy, r, sectorRatio } =
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

        makeSectorBoundary angle =
            line
                [ x1 (px (cx + (r - 10) * cos angle))
                , y1 (px (cy + (r - 10) * sin angle))
                , x2 (px (cx + (r + 10) * cos angle))
                , y2 (px (cy + (r + 10) * sin angle))
                , stroke "#aaa"
                , strokeWidth (px 3)
                ]
                []

        ( s1Angle, s2Angle ) =
            ( (2 * pi * sectorRatio.s1) - (pi / 2)
            , (2 * pi * (sectorRatio.s1 + sectorRatio.s2)) - (pi / 2)
            )

        ( sector1Boundary, sector2Boundary ) =
            ( makeSectorBoundary s1Angle
            , makeSectorBoundary s2Angle
            )
    in
    g [] [ trackCircle, startFinishLine, sector1Boundary, sector2Boundary ]


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
coordinatesOnTrack { cx, cy, r, sectorRatio } car =
    let
        progress =
            calcProgress sectorRatio car

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


calcProgress : { s1 : Float, s2 : Float, s3 : Float } -> ViewModelItem -> Float
calcProgress ratio car =
    case car.timing.sector of
        Just ( S1, progress ) ->
            (progress / 100) * ratio.s1

        Just ( S2, progress ) ->
            ratio.s1 + (progress / 100) * ratio.s2

        Just ( S3, progress ) ->
            ratio.s1 + ratio.s2 + (progress / 100) * ratio.s3

        -- Fallback to the original calculation if sector data is incomplete
        Nothing ->
            case car.currentLap of
                Nothing ->
                    0

                Just currentLap ->
                    min 1.0 (toFloat car.timing.time / toFloat currentLap.time)
