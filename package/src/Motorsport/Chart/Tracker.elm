module Motorsport.Chart.Tracker exposing (view)

import Css
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
import Svg.Styled exposing (Svg, circle, g, line, rect, svg, text, text_)
import Svg.Styled.Attributes exposing (css, dominantBaseline, fill, stroke, textAnchor)
import Svg.Styled.Keyed as Keyed
import Svg.Styled.Lazy as Lazy
import TypedSvg.Styled.Attributes as Attributes exposing (cx, cy, fontSize, height, r, strokeWidth, viewBox, width, x1, x2, y1, y2)
import TypedSvg.Types exposing (Transform(..), num, px)


type alias Constants =
    { viewBox : { w : Float, h : Float }
    , track :
        { cx : Float
        , cy : Float
        , r : Float
        , bandWidth : Float
        , startFinishLineExtension : Float
        , startFinishLineStrokeWidth : Float
        , sectorBoundaryOffset : Float
        , sectorBoundaryStrokeWidth : Float
        , sectorLabelRadius : Float
        , sectorLabelFontSize : Float
        , miniSectorLabelRadius : Float
        , miniSectorLabelFontSize : Float
        }
    , car :
        { barLength : Float
        , barWidth : Float
        , labelRadius : Float
        , labelFontSize : Float
        }
    }


constants : Constants
constants =
    let
        viewBoxWidth =
            800

        viewBoxHeight =
            600
    in
    { viewBox = { w = viewBoxWidth, h = viewBoxHeight }
    , track =
        { cx = viewBoxWidth / 2
        , cy = viewBoxHeight / 2
        , r = 250
        , bandWidth = 20
        , startFinishLineExtension = 15
        , startFinishLineStrokeWidth = 2
        , sectorBoundaryOffset = 10
        , sectorBoundaryStrokeWidth = 2
        , sectorLabelRadius = 300
        , sectorLabelFontSize = 16
        , miniSectorLabelRadius = 220
        , miniSectorLabelFontSize = 10
        }
    , car =
        { barLength = 20
        , barWidth = 3
        , labelRadius = 275
        , labelFontSize = 10
        }
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
            constants.viewBox
    in
    svg
        [ viewBox 0 0 w h
        , css [ Css.maxWidth (Css.pct 100), Css.maxHeight (Css.pct 100) ]
        ]
        [ Lazy.lazy2 track direction config
        , renderCars direction config vm
        ]


track : Direction -> TrackConfig -> Svg msg
track direction config =
    let
        { cx, cy, r, bandWidth } =
            constants.track

        trackBand =
            circle
                [ Attributes.cx (px cx)
                , Attributes.cy (px cy)
                , Attributes.r (px r)
                , fill "none"
                , stroke "oklch(1 0 0 / 0.1)"
                , strokeWidth (px bandWidth)
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
    g [] ([ trackBand ] ++ boundaries ++ [ startFinishLine ] ++ sectorLabels ++ miniSectorLabels)


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
                    , color = "oklch(1 0 0 / 0.5)"
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
    let
        coords =
            coordinatesOnTrack direction config car
    in
    renderCar direction car coords


coordinatesOnTrack : Direction -> TrackConfig -> ViewModelItem -> { angle : Float, x : Float, y : Float }
coordinatesOnTrack direction config car =
    let
        { cx, cy, r } =
            constants.track

        progress =
            Config.computeProgress config car

        angle =
            Scale.convert (progressToAngleScale direction) progress
    in
    { angle = angle
    , x = cx + r * cos angle
    , y = cy + r * sin angle
    }


renderCar : Direction -> ViewModelItem -> { angle : Float, x : Float, y : Float } -> Svg msg
renderCar direction car { angle, x, y } =
    let
        { carNumber, class } =
            car.metadata

        { cx, cy } =
            constants.track

        labelRadius =
            constants.car.labelRadius

        labelX =
            cx + labelRadius * cos angle

        labelY =
            cy + labelRadius * sin angle
    in
    g []
        [ g [ Attributes.transform [ Translate x y, Rotate (angle * 180 / pi + 90) 0 0 ] ]
            [ Lazy.lazy2 carMarker car.positionInClass class ]
        , carLabel { x = labelX, y = labelY } { carNumber = carNumber }
        ]


carMarker : Int -> Class -> Svg msg
carMarker positionInClass class =
    let
        -- 長さのスケール係数（より大きな差を付ける）
        lengthScale =
            max 0.5 (1 - (toFloat (positionInClass - 1) * 0.025))

        -- 幅のスケール係数（緩やかな変化）
        widthScale =
            max 0.5 (1 - (toFloat (positionInClass - 1) * 0.25))

        barLength =
            constants.car.barLength * lengthScale

        barWidth =
            constants.car.barWidth * widthScale

        saturation =
            if positionInClass <= 3 then
                "100%"

            else
                "60%"

        -- 順位による透明度の変化
        opacity =
            if positionInClass <= 5 then
                1.0

            else
                max 0.7 (1 - (toFloat (positionInClass - 6) * 0.05))
    in
    rect
        [ Attributes.x (px (-barWidth / 2))
        , Attributes.y (px (-barLength / 2))
        , Attributes.width (px barWidth)
        , Attributes.height (px barLength)
        , fill (Class.toHexColor 2025 class |> .value)
        , css
            [ Css.property "filter" ("saturate(" ++ saturation ++ ")")
            , Css.opacity (Css.num opacity)
            ]
        ]
        []


carLabel : { x : Float, y : Float } -> { carNumber : String } -> Svg msg
carLabel { x, y } { carNumber } =
    text_
        [ Attributes.x (px x)
        , Attributes.y (px y)
        , fontSize (px constants.car.labelFontSize)
        , textAnchor "middle"
        , dominantBaseline "central"
        , fill "oklch(1 0 0)"
        ]
        [ text carNumber ]
