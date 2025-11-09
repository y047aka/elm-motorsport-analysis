module Motorsport.Chart.Tracker exposing (view)

import Css exposing (maxWidth, pct)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.Tracker.Config as Config exposing (MiniSectorData(..), TrackConfig)
import Motorsport.Circuit as Circuit
import Motorsport.Circuit.LeMans as LeMans
import Motorsport.Class as Class exposing (Class)
import Motorsport.Direction exposing (Direction(..))
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Sector as Sector
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
        , sectorLabelRadius : Float
        , sectorLabelFontSize : Float
        , miniSectorLabelRadius : Float
        , miniSectorLabelFontSize : Float
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
        , r = 400
        , trackWidth = 8
        , startFinishLineExtension = 20
        , startFinishLineStrokeWidth = 4
        , sectorBoundaryOffset = 10
        , sectorBoundaryStrokeWidth = 4
        , sectorLabelRadius = 430
        , sectorLabelFontSize = 20
        , miniSectorLabelRadius = 370
        , miniSectorLabelFontSize = 12
        }
    , car = { size = 15 }
    }


{-| トラック上の進捗値（0-1）を角度（ラジアン）に変換するスケール関数
回転方向に応じて12時の位置から時計回り、または反時計回りに0-2πの範囲で変換
-}
progressToAngleScale : Direction -> ContinuousScale Float
progressToAngleScale direction =
    let
        quarterTurn =
            pi / 2
    in
    case direction of
        Clockwise ->
            -- 12時の位置から時計回りに0-2πの範囲で変換
            Scale.linear ( -quarterTurn, -quarterTurn + 2 * pi ) ( 0, 1 )

        CounterClockwise ->
            -- 12時の位置から反時計回りに0-2πの範囲で変換
            Scale.linear ( -quarterTurn, -quarterTurn - 2 * pi ) ( 0, 1 )


view : { season : Int, eventName : String } -> Analysis -> ViewModel -> Svg msg
view { season, eventName } analysis vm =
    let
        layout =
            if season == 2025 && eventName == "24 Hours of Le Mans" then
                Circuit.leMans2025

            else if isCounterClockwiseCircuit eventName then
                Circuit.counterClockwise

            else
                Circuit.clockwise

        config =
            Config.buildConfig layout analysis
    in
    viewWithConfig layout.direction config vm


{-| Check if a circuit runs counter-clockwise
-}
isCounterClockwiseCircuit : String -> Bool
isCounterClockwiseCircuit eventName =
    List.member eventName
        [ "Lone Star Le Mans"
        , "6 Hours of Imola"
        , "6 Hours of São Paulo"
        ]


viewWithConfig : Direction -> TrackConfig -> ViewModel -> Svg msg
viewWithConfig direction config vm =
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
        [ Lazy.lazy2 track direction config
        , renderCars direction config vm
        ]


track : Direction -> TrackConfig -> Svg msg
track direction config =
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
                |> List.map (Scale.convert (progressToAngleScale direction))
                |> List.map (\angle -> makeBoundary angle)

        sectorLabels =
            renderSectorLabels direction config

        miniSectorLabels =
            renderMiniSectorLabels direction config
    in
    g [] ([ outerTrackCircle, innerTrackCircle, startFinishLine ] ++ boundaries ++ sectorLabels ++ miniSectorLabels)


renderSectorLabels : Direction -> TrackConfig -> List (Svg msg)
renderSectorLabels direction config =
    config
        |> List.map
            (\sectorConfig ->
                let
                    progress =
                        sectorConfig.start + (sectorConfig.share / 2)

                    label =
                        Sector.toString sectorConfig.sector
                in
                makeLabel direction
                    { progress = progress
                    , radius = constants.track.sectorLabelRadius
                    , fontSize = constants.track.sectorLabelFontSize
                    , color = "oklch(1 0 0)"
                    , label = label
                    }
            )


renderMiniSectorLabels : Direction -> TrackConfig -> List (Svg msg)
renderMiniSectorLabels direction config =
    config
        |> List.concatMap
            (\sectorConfig ->
                case sectorConfig.miniSectorData of
                    Config.NoMiniSectors ->
                        []

                    Config.WithMiniSectors minis ->
                        minis
                            |> List.map
                                (\miniShare ->
                                    let
                                        progress =
                                            miniShare.start + miniShare.share

                                        label =
                                            LeMans.miniSectorToString miniShare.mini
                                    in
                                    makeLabel direction
                                        { progress = progress
                                        , radius = constants.track.miniSectorLabelRadius
                                        , fontSize = constants.track.miniSectorLabelFontSize
                                        , color = "oklch(0.5 0 0)"
                                        , label = label
                                        }
                                )
            )


makeLabel :
    Direction
    ->
        { progress : Float
        , radius : Float
        , fontSize : Float
        , color : String
        , label : String
        }
    -> Svg msg
makeLabel direction { progress, radius, fontSize, color, label } =
    let
        { cx, cy } =
            constants.track

        angle =
            Scale.convert (progressToAngleScale direction) progress

        labelX =
            cx + radius * cos angle

        labelY =
            cy + radius * sin angle
    in
    text_
        [ Attributes.x (px labelX)
        , Attributes.y (px labelY)
        , Attributes.fontSize (px fontSize)
        , textAnchor "middle"
        , dominantBaseline "central"
        , fill color
        ]
        [ text label ]


renderCars : Direction -> TrackConfig -> ViewModel -> Svg msg
renderCars direction config viewModel =
    Keyed.node "g"
        []
        (SortedList.toList viewModel.items
            |> List.reverse
            |> List.map
                (\car ->
                    ( car.metadata.carNumber
                    , Lazy.lazy3 renderCarOnTrack direction config car
                    )
                )
        )


renderCarOnTrack : Direction -> TrackConfig -> ViewModelItem -> Svg msg
renderCarOnTrack direction config car =
    coordinatesOnTrack direction config car
        |> renderCar car


coordinatesOnTrack : Direction -> TrackConfig -> ViewModelItem -> { x : Float, y : Float }
coordinatesOnTrack direction config car =
    let
        { cx, cy, r } =
            constants.track

        progress =
            Config.computeProgress config car

        angle =
            Scale.convert (progressToAngleScale direction) progress
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
