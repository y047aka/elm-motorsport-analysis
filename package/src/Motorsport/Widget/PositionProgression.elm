module Motorsport.Widget.PositionProgression exposing (view)

import Axis exposing (tickCount, tickFormat, tickSizeInner, tickSizeOuter)
import Color
import Css
import Css.Extra
import Css.Global exposing (descendants, each)
import Html.Styled as Html exposing (Html, div, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import Motorsport.Class as Class exposing (Class)
import Motorsport.Clock as Clock
import Motorsport.Lap exposing (Lap)
import Motorsport.RaceControl.ViewModel exposing (ViewModel)
import Motorsport.Widget as Widget
import Path
import Scale exposing (ContinuousScale)
import Shape
import SortedList
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, svg)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Attributes as TA
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Length(..), Opacity(..), Paint(..), Transform(..))



-- Chart configuration


w : Float
w =
    320


h : Float
h =
    180


padding : Float
padding =
    15


paddingLeft : Float
paddingLeft =
    padding + 35


paddingBottom : Float
paddingBottom =
    padding + 15


type alias PositionPoint =
    { lapNumber : Int
    , position : Int
    }


type alias CarPositionData =
    { carNumber : String
    , positions : List PositionPoint
    , color : Color.Color
    }


type alias ClassPositionData =
    { class : Class
    , cars : List CarPositionData
    , carCount : Int
    }


view : Clock.Model -> ViewModel -> Html msg
view clock viewModel =
    let
        classDataList =
            processClassPositionData clock viewModel
    in
    Widget.container "Position Progression"
        (separateClassChartsView classDataList)


processClassPositionData : Clock.Model -> ViewModel -> List ClassPositionData
processClassPositionData clock viewModel =
    let
        currentRaceTime =
            Clock.getElapsed clock

        timeThreshold =
            currentRaceTime - (60 * 60 * 1000)

        lapThreshold =
            SortedList.toList viewModel.items
                |> List.head
                |> Maybe.map .history
                |> Maybe.andThen (List.Extra.find (\{ elapsed } -> elapsed >= timeThreshold))
                |> Maybe.map .lap
                |> Maybe.withDefault 1
    in
    SortedList.toList viewModel.items
        |> List.Extra.gatherEqualsBy (.metaData >> .class)
        |> List.map (\( first, rest ) -> ( first.metaData.class, first :: rest ))
        |> List.map
            (\( class, carsInClass ) ->
                let
                    cars =
                        carsInClass
                            |> List.map
                                (\car ->
                                    let
                                        positionHistory =
                                            extractPositionDataForCar lapThreshold car.history
                                    in
                                    { carNumber = car.metaData.carNumber
                                    , positions = positionHistory
                                    , color = generateCarColor car.metaData.carNumber
                                    }
                                )
                            |> List.filter (\car -> List.length car.positions >= 2)
                in
                { class = class
                , cars = cars
                , carCount = List.length carsInClass
                }
            )
        |> List.filter (\classData -> List.length classData.cars > 0)
        |> List.sortBy (.class >> Class.toString)


extractPositionDataForCar : Int -> List Lap -> List PositionPoint
extractPositionDataForCar lapThreshold laps =
    laps
        |> List.filter (\lap -> lap.lap >= lapThreshold)
        |> List.filterMap
            (\lap ->
                case lap.position of
                    Just pos ->
                        Just { lapNumber = lap.lap, position = pos }

                    Nothing ->
                        Nothing
            )


generateCarColor : String -> Color.Color
generateCarColor carNumber =
    let
        carHash =
            String.toInt carNumber |> Maybe.withDefault 0

        ( hue, saturation, lightness ) =
            ( carHash * 37 |> modBy 360 |> toFloat
            , 0.7 + (toFloat (carHash * 17 |> modBy 30) / 100)
            , 0.5 + (toFloat (carHash * 13 |> modBy 20) / 100)
            )
    in
    Color.hsl (hue / 360) saturation lightness


colorToCss : Color.Color -> Css.Color
colorToCss color =
    let
        rgba =
            Color.toRgba color
    in
    Css.rgba (round (rgba.red * 255)) (round (rgba.green * 255)) (round (rgba.blue * 255)) rgba.alpha


separateClassChartsView : List ClassPositionData -> Html msg
separateClassChartsView classDataList =
    if List.isEmpty classDataList then
        Widget.emptyState "No position progression data available"

    else
        div
            [ css
                [ Css.property "display" "grid"
                , Css.property "row-gap" "15px"
                ]
            ]
            (classDataList |> List.map singleClassPositionChartView)


singleClassPositionChartView : ClassPositionData -> Html msg
singleClassPositionChartView { class, cars, carCount } =
    if List.isEmpty cars then
        div [] []

    else
        div
            [ css
                [ Css.property "display" "grid"
                , Css.property "row-gap" "8px"
                ]
            ]
            [ Widget.classHeader class
                [ text
                    (String.join " | "
                        [ String.fromInt (List.length cars) ++ " cars showing"
                        , String.fromInt carCount ++ " total"
                        ]
                    )
                ]
            , svg
                [ InPx.width w
                , InPx.height h
                , viewBox 0 0 w h
                ]
                (let
                    allPositions =
                        List.concatMap .positions cars
                 in
                 [ xAxis allPositions
                 , yAxis allPositions
                 ]
                    ++ renderClassPositionLines cars allPositions
                )
            ]



-- Scales


xScale : List PositionPoint -> ContinuousScale Float
xScale positions =
    let
        ( minLap, maxLap ) =
            positions
                |> List.map .lapNumber
                |> (\laps ->
                        ( List.minimum laps |> Maybe.withDefault 1
                        , List.maximum laps |> Maybe.withDefault 1
                        )
                   )
    in
    Scale.linear ( paddingLeft, w - padding ) ( toFloat minLap, toFloat maxLap )


yScale : List PositionPoint -> ContinuousScale Float
yScale positions =
    let
        allPositions =
            positions |> List.map .position

        ( minPos, maxPos ) =
            ( List.minimum allPositions |> Maybe.withDefault 1
            , List.maximum allPositions |> Maybe.withDefault 1
            )

        -- Add some padding to the range
        padding_y =
            max 1 ((maxPos - minPos) // 10)

        adjustedMin =
            max 1 (minPos - padding_y)

        adjustedMax =
            maxPos + padding_y
    in
    Scale.linear ( h - paddingBottom, padding ) ( toFloat adjustedMax, toFloat adjustedMin )



-- Axes


xAxis : List PositionPoint -> Svg msg
xAxis positions =
    let
        axis =
            fromUnstyled <|
                Axis.bottom
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 3
                    , tickFormat (round >> String.fromInt)
                    ]
                    (xScale positions)
    in
    g
        [ SvgAttr.css
            [ descendants
                [ Css.Global.typeSelector "text"
                    [ Css.fill (Css.hsl 0 0 0.7)
                    , Css.fontSize (Css.px 9)
                    ]
                , each
                    [ Css.Global.typeSelector "line"
                    , Css.Global.typeSelector "path"
                    ]
                    [ Css.Extra.strokeWidth 1
                    , Css.property "stroke" "#555"
                    ]
                ]
            ]
        , transform [ Translate 0 (h - paddingBottom) ]
        ]
        [ axis ]


yAxis : List PositionPoint -> Svg msg
yAxis positions =
    let
        allPositions =
            positions |> List.map .position

        positionRange =
            (List.maximum allPositions |> Maybe.withDefault 1) - (List.minimum allPositions |> Maybe.withDefault 1) + 1

        tickCount_ =
            min 5 (max 2 positionRange)

        axis =
            fromUnstyled <|
                Axis.left
                    [ tickCount tickCount_
                    , tickSizeOuter 0
                    , tickSizeInner 5
                    , tickFormat (round >> String.fromInt)
                    ]
                    (yScale positions)
    in
    g
        [ SvgAttr.css
            [ descendants
                [ Css.Global.typeSelector "text"
                    [ Css.fill (Css.hsl 0 0 0.7)
                    , Css.fontSize (Css.px 9)
                    ]
                , each
                    [ Css.Global.typeSelector "line"
                    , Css.Global.typeSelector "path"
                    ]
                    [ Css.Extra.strokeWidth 1
                    , Css.property "stroke" "#555"
                    ]
                ]
            ]
        , transform [ Translate paddingLeft 0 ]
        ]
        [ axis ]



-- Rendering


renderClassPositionLines : List CarPositionData -> List PositionPoint -> List (Svg msg)
renderClassPositionLines cars allPositions =
    cars
        |> List.concatMap (renderCarPositionLine allPositions)


renderCarPositionLine : List PositionPoint -> CarPositionData -> List (Svg msg)
renderCarPositionLine allPositions carData =
    let
        dataPoints =
            carData.positions
                |> List.map
                    (\{ lapNumber, position } ->
                        ( lapNumber
                            |> toFloat
                            |> Scale.convert (xScale allPositions)
                        , position
                            |> toFloat
                            |> Scale.convert (yScale allPositions)
                        )
                    )

        linePath =
            dataPoints
                |> List.map Just
                |> Shape.line Shape.linearCurve

        points =
            List.map point dataPoints

        point ( x, y ) =
            circle
                [ InPx.cx x
                , InPx.cy y
                , InPx.r 2
                , SvgAttr.css
                    [ Css.fill (colorToCss carData.color)
                    , Css.opacity (Css.num 0.8)
                    ]
                ]
                []
    in
    (fromUnstyled <|
        Path.element linePath
            [ TA.stroke (Paint carData.color)
            , TA.strokeWidth (Px 1.5)
            , TA.fill PaintNone
            , TA.strokeOpacity (Opacity 0.7)
            ]
    )
        :: points
