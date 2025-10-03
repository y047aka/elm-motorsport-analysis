module Motorsport.Chart.Tracker exposing (view)

import Css exposing (maxWidth, pct)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.Tracker.Config as Config exposing (TrackConfig)
import Motorsport.Circuit as Circuit
import Motorsport.Class as Class exposing (Class)
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Scale exposing (ContinuousScale)
import SortedList
import Svg.Styled exposing (Svg, circle, g, line, svg, text, text_)
import Svg.Styled.Attributes exposing (css, dominantBaseline, fill, stroke, textAnchor)
import Svg.Styled.Keyed as Keyed
import Svg.Styled.Lazy as Lazy
import TypedSvg.Styled.Attributes as Attributes exposing (cx, cy, fontSize, height, r, strokeWidth, viewBox, width, x1, x2, y1, y2)
import TypedSvg.Types exposing (Transform(..), px)


type alias Constants =
    { svg : { w : Float, h : Float }
    , track :
        { cx : Float
        , cy : Float
        , r : Float
        , trackWidth : Float
        , startFinishLineExtension : Float
        , startFinishLineStrokeWidth : Float
        , sectorBoundaryOffset : Float
        , sectorBoundaryStrokeWidth : Float
        }
    , car : { size : Float }
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
        , trackWidth = 8
        , startFinishLineExtension = 20
        , startFinishLineStrokeWidth = 4
        , sectorBoundaryOffset = 10
        , sectorBoundaryStrokeWidth = 4
        }
    , car = { size = 15 }
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


view : Bool -> Analysis -> ViewModel -> Svg msg
view isLeMans2025 analysis vm =
    let
        layout =
            if isLeMans2025 then
                Circuit.leMans2025

            else
                Circuit.standard

        config =
            Config.buildConfig layout analysis
    in
    viewWithConfig config vm


viewWithConfig : TrackConfig -> ViewModel -> Svg msg
viewWithConfig config vm =
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
        , renderCars config vm
        ]


track : TrackConfig -> Svg msg
track config =
    let
        { cx, cy, r, trackWidth } =
            constants.track

        trackCircle color width =
            circle
                [ Attributes.cx (px cx)
                , Attributes.cy (px cy)
                , Attributes.r (px r)
                , fill "none"
                , stroke color
                , strokeWidth (px width)
                ]
                []

        outerTrackCircle =
            trackCircle "#eee" (trackWidth + 8)

        innerTrackCircle =
            trackCircle "oklch(0.2 0 0)" trackWidth

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
                , stroke "oklch(0.2 0 0)"
                , strokeWidth (px constants.track.sectorBoundaryStrokeWidth)
                ]
                []

        boundaries =
            Config.calcSectorBoundaries config
                |> List.map (Scale.convert progressToAngleScale)
                |> List.map (\angle -> makeBoundary angle)
    in
    g [] ([ outerTrackCircle, innerTrackCircle, startFinishLine ] ++ boundaries)


renderCars : TrackConfig -> ViewModel -> Svg msg
renderCars config viewModel =
    Keyed.node "g"
        []
        (SortedList.toList viewModel.items
            |> List.reverse
            |> List.map
                (\car ->
                    ( car.metadata.carNumber
                    , Lazy.lazy2 renderCarOnTrack config car
                    )
                )
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
        { carNumber, class } =
            car.metadata
    in
    g [ Attributes.transform [ Translate x y ] ]
        [ Lazy.lazy2 carWithPositionInClass car.positionInClass { carNumber = carNumber, class = class } ]


carWithPositionInClass : Int -> { carNumber : String, class : Class } -> Svg msg
carWithPositionInClass positionInClass d =
    let
        ( carSize, saturation ) =
            let
                scaleFactor =
                    max 0.75 (1 - (toFloat (positionInClass - 1) * 0.05))
            in
            ( constants.car.size * scaleFactor
            , if positionInClass <= 3 then
                "100%"

              else
                "60%"
            )

        carCircle =
            circle
                [ Attributes.cx (px 0)
                , Attributes.cy (px 0)
                , Attributes.r (px carSize)
                , fill (Class.toHexColor 2025 d.class |> .value)
                , css [ Css.property "filter" ("saturate(" ++ saturation ++ ")") ]
                ]
                []

        carNumber =
            text_
                [ Attributes.x (px 0)
                , Attributes.y (px 0)
                , fontSize (px carSize)
                , textAnchor "middle"
                , dominantBaseline "central"
                , fill "#fff"
                ]
                [ text d.carNumber ]
    in
    g [] [ carCircle, carNumber ]
