module Motorsport.Chart.Tracker exposing (view, viewWithMiniSectors)

import Css exposing (maxWidth, pct)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.Tracker.Config as Config exposing (TrackConfig)
import Motorsport.Class as Class
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel as ViewModel exposing (ViewModelItem)
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg, circle, g, line, svg, text, text_)
import Svg.Styled.Attributes exposing (css, dominantBaseline, fill, stroke, textAnchor)
import Svg.Styled.Keyed as Keyed
import Svg.Styled.Lazy as Lazy
import TypedSvg.Styled.Attributes as Attributes exposing (cx, cy, fontSize, height, r, strokeWidth, viewBox, width, x1, x2, y1, y2)
import TypedSvg.Types exposing (px)


type alias Constants =
    { svg : { w : Float, h : Float }
    , track :
        { cx : Float
        , cy : Float
        , r : Float
        , strokeWidth : Float
        , startFinishLineExtension : Float
        , startFinishLineStrokeWidth : Float
        , sectorBoundaryOffset : Float
        , sectorBoundaryStrokeWidth : Float
        }
    , car : { radius : Float, numberFontSize : Float }
    }


constants : Constants
constants =
    let
        size =
            1000
    in
    { svg = { w = size, h = size }
    , track =
        { cx = size / 2
        , cy = size / 2
        , r = 450
        , strokeWidth = 4
        , startFinishLineExtension = 15
        , startFinishLineStrokeWidth = 4
        , sectorBoundaryOffset = 10
        , sectorBoundaryStrokeWidth = 3
        }
    , car = { radius = 15, numberFontSize = 15 }
    }


{-| トラック上の進捗値（0-1）を角度（ラジアン）に変換するスケール関数
12時の位置から時計回りに0-2πの範囲で変換
-}
progressToAngleScale : ContinuousScale Float
progressToAngleScale =
    let
        quarterTurn =
            pi / 2
    in
    Scale.linear ( -quarterTurn, -quarterTurn + 2 * pi ) ( 0, 1 )


view : Analysis -> RaceControl.Model -> Svg msg
view analysis raceControl =
    let
        config =
            Config.standard analysis
    in
    viewWithConfig config raceControl


viewWithMiniSectors : Analysis -> RaceControl.Model -> Svg msg
viewWithMiniSectors analysis raceControl =
    let
        config =
            Config.leMans24h analysis
    in
    viewWithConfig config raceControl


viewWithConfig : TrackConfig -> RaceControl.Model -> Svg msg
viewWithConfig config raceControl =
    let
        { w, h } =
            constants.svg
    in
    svg
        [ width (px w)
        , height (px h)
        , viewBox 0 0 w h
        , css [ maxWidth (pct 100) ]
        ]
        [ Lazy.lazy track config
        , renderCars config raceControl
        ]


track : TrackConfig -> Svg msg
track config =
    let
        { cx, cy, r } =
            constants.track

        trackCircle =
            circle
                [ Attributes.cx (px cx)
                , Attributes.cy (px cy)
                , Attributes.r (px r)
                , fill "none"
                , stroke "#333"
                , strokeWidth (px constants.track.strokeWidth)
                ]
                []

        startFinishLine =
            line
                [ x1 (px cx)
                , y1 (px (cy - r - constants.track.startFinishLineExtension))
                , x2 (px cx)
                , y2 (px (cy - r + constants.track.startFinishLineExtension))
                , stroke "#fff"
                , strokeWidth (px constants.track.startFinishLineStrokeWidth)
                ]
                []

        makeBoundary angle =
            line
                [ x1 (px (cx + (r - constants.track.sectorBoundaryOffset) * cos angle))
                , y1 (px (cy + (r - constants.track.sectorBoundaryOffset) * sin angle))
                , x2 (px (cx + (r + constants.track.sectorBoundaryOffset) * cos angle))
                , y2 (px (cy + (r + constants.track.sectorBoundaryOffset) * sin angle))
                , stroke "#aaa"
                , strokeWidth (px constants.track.sectorBoundaryStrokeWidth)
                ]
                []

        boundaries =
            Config.calcSectorBoundaries config
                |> List.map (Scale.convert progressToAngleScale)
                |> List.map (\angle -> makeBoundary angle)
    in
    g [] (trackCircle :: startFinishLine :: boundaries)


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
coordinatesOnTrack config car =
    let
        { cx, cy, r } =
            constants.track

        progress =
            Config.calcSectorProgress config car

        angle =
            Scale.convert progressToAngleScale progress
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
                , Attributes.r (px constants.car.radius)
                , fill carColor
                ]
                []

        carNumber =
            text_
                [ Attributes.x (px x)
                , Attributes.y (px y)
                , fontSize (px constants.car.numberFontSize)
                , textAnchor "middle"
                , dominantBaseline "central"
                , fill "#fff"
                ]
                [ text car.metaData.carNumber ]
    in
    g [] [ carCircle, carNumber ]
