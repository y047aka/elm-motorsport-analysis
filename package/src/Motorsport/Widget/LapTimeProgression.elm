module Motorsport.Widget.LapTimeProgression exposing (view)

import Axis exposing (tickCount, tickFormat, tickSizeInner, tickSizeOuter)
import Color
import Css
import Css.Extra
import Css.Global exposing (descendants, each)
import Html.Styled as Html exposing (Html, div, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import Motorsport.Class exposing (Class)
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
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


type alias CarProgressionData =
    { carNumber : String
    , laps : List Lap
    , color : Color.Color
    }


type alias ClassProgressionData =
    { class : Class
    , cars : List CarProgressionData
    , averageLapTime : Duration
    }


view : Clock.Model -> ViewModel -> Html msg
view clock viewModel =
    let
        classDataList =
            processClassProgressionData clock viewModel
    in
    Widget.container "Lap Time Progression"
        (separateClassChartsView classDataList)


processClassProgressionData : Clock.Model -> ViewModel -> List ClassProgressionData
processClassProgressionData clock viewModel =
    viewModel.itemsByClass
        |> List.map
            (\( class, carsInClass ) ->
                let
                    cars =
                        SortedList.toList carsInClass
                            |> List.map
                                (\car ->
                                    let
                                        allLaps =
                                            extractLapDataForCar clock car.history
                                    in
                                    { carNumber = car.metaData.carNumber
                                    , laps = allLaps
                                    , color = Manufacturer.toColorWithFallback car.metaData
                                    }
                                )
                            |> List.filter (\car -> List.length car.laps >= 2)

                    averageLapTime =
                        let
                            latestLapTimes =
                                cars
                                    |> List.filterMap (\car -> List.Extra.last car.laps)
                                    |> filterOutlierLaps
                                    |> List.map .time
                        in
                        case latestLapTimes of
                            [] ->
                                999999

                            lapTimes ->
                                List.sum lapTimes // List.length lapTimes
                in
                { class = class
                , cars = cars
                , averageLapTime = averageLapTime
                }
            )
        |> List.filter (\classData -> List.length classData.cars > 0)
        |> List.sortBy .averageLapTime


extractLapDataForCar : Clock.Model -> List Lap -> List Lap
extractLapDataForCar clock laps =
    let
        currentRaceTime =
            Clock.getElapsed clock

        timeThreshold =
            currentRaceTime - (60 * 60 * 1000)
    in
    laps
        |> List.filter (\lap -> timeThreshold <= lap.elapsed && lap.elapsed <= currentRaceTime)


filterOutlierLaps : List Lap -> List Lap
filterOutlierLaps laps =
    let
        fastestTime =
            laps
                |> List.map .time
                |> List.minimum
                |> Maybe.withDefault 999999

        threshold =
            toFloat fastestTime * 1.1 |> round
    in
    laps
        |> List.filter (\lap -> lap.time <= threshold)


colorToCss : Color.Color -> Css.Color
colorToCss color =
    let
        rgba =
            Color.toRgba color
    in
    Css.rgba (round (rgba.red * 255)) (round (rgba.green * 255)) (round (rgba.blue * 255)) rgba.alpha


separateClassChartsView : List ClassProgressionData -> Html msg
separateClassChartsView classDataList =
    if List.isEmpty classDataList then
        Widget.emptyState "No lap progression data available"

    else
        div
            [ css
                [ Css.property "display" "grid"
                , Css.property "row-gap" "15px"
                ]
            ]
            (classDataList |> List.map singleClassProgressionChartView)


singleClassProgressionChartView : ClassProgressionData -> Html msg
singleClassProgressionChartView { class, cars, averageLapTime } =
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
                        [ "Avg: " ++ Duration.toString averageLapTime
                        , String.fromInt (List.length cars) ++ " cars"
                        ]
                    )
                ]
            , svg
                [ InPx.width w
                , InPx.height h
                , viewBox 0 0 w h
                ]
                ([ xAxis (List.concatMap .laps cars)
                 , yAxis (List.concatMap .laps cars)
                 ]
                    ++ renderClassProgressionLines cars
                )
            ]



-- Scales


xScale : List Lap -> ContinuousScale Float
xScale laps =
    let
        ( minTime, maxTime ) =
            laps
                |> List.map .elapsed
                |> (\ts ->
                        ( List.minimum ts |> Maybe.withDefault 0
                        , List.maximum ts |> Maybe.withDefault 0
                        )
                   )
    in
    Scale.linear ( paddingLeft, w - padding ) ( toFloat minTime, toFloat maxTime )


yScale : List Lap -> ContinuousScale Float
yScale laps =
    let
        ( minTime, maxTime ) =
            laps
                |> filterOutlierLaps
                |> List.map .time
                |> (\ts ->
                        ( List.minimum ts |> Maybe.withDefault 0 |> toFloat
                        , List.maximum ts |> Maybe.withDefault 0 |> toFloat
                        )
                   )

        padding_y =
            (maxTime - minTime) * 0.1

        ( adjustedMin, adjustedMax ) =
            ( minTime - padding_y
            , maxTime + padding_y
            )
    in
    Scale.linear ( h - paddingBottom, padding ) ( adjustedMin, adjustedMax )



-- Axes


xAxis : List Lap -> Svg msg
xAxis laps =
    let
        axis =
            fromUnstyled <|
                Axis.bottom
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 3
                    , tickFormat (round >> Duration.toString)
                    ]
                    (xScale laps)
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


yAxis : List Lap -> Svg msg
yAxis laps =
    let
        axis =
            fromUnstyled <|
                Axis.left
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 5
                    , tickFormat (round >> Duration.toString)
                    ]
                    (yScale laps)
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


renderClassProgressionLines : List CarProgressionData -> List (Svg msg)
renderClassProgressionLines cars =
    cars
        |> List.concatMap (renderCarProgressionLine (List.concatMap .laps cars))


renderCarProgressionLine : List Lap -> CarProgressionData -> List (Svg msg)
renderCarProgressionLine laps carData =
    let
        dataPoints =
            carData.laps
                |> List.map
                    (\{ time, elapsed } ->
                        ( elapsed
                            |> toFloat
                            |> Scale.convert (xScale laps)
                        , time
                            |> toFloat
                            |> Scale.convert (yScale laps)
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
                    , Css.property "stroke" "none"
                    ]
                ]
                []
    in
    (fromUnstyled <|
        Path.element linePath
            [ TA.stroke (Paint carData.color)
            , TA.strokeWidth (Px 1.5)
            , TA.fill PaintNone
            ]
    )
        :: points
