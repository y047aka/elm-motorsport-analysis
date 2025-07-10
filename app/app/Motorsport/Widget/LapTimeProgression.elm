module Motorsport.Widget.LapTimeProgression exposing (view)

import Axis exposing (tickCount, tickFormat, tickSizeInner, tickSizeOuter)
import Color
import Css
import Css.Extra
import Css.Global exposing (descendants, each)
import Html.Styled as Html exposing (Html, div, h3, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import Motorsport.Class as Class exposing (Class)
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Path
import Scale exposing (ContinuousScale)
import Shape
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
    , averageLapTime : Duration
    , totalLaps : Int
    }


type alias ClassProgressionData =
    { class : Class
    , cars : List CarProgressionData
    , averageLapTime : Duration
    , totalCars : Int
    }


view : Clock.Model -> ViewModel -> Html msg
view clock viewModel =
    let
        classDataList =
            processClassProgressionData clock viewModel
    in
    div
        [ css
            [ Css.padding (Css.px 10)
            , Css.backgroundColor (Css.hsl 0 0 0.2)
            , Css.borderRadius (Css.px 12)
            , Css.height (Css.pct 100)
            , Css.property "display" "grid"
            , Css.property "grid-template-rows" "auto 1fr"
            , Css.property "row-gap" "10px"
            ]
        ]
        [ titleView
        , separateClassChartsView classDataList
        ]


processClassProgressionData : Clock.Model -> ViewModel -> List ClassProgressionData
processClassProgressionData clock viewModel =
    viewModel
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
                                        allLaps =
                                            extractLapDataForCar clock car

                                        normalLaps =
                                            filterOutlierLaps allLaps

                                        lapTimes =
                                            List.map .time normalLaps

                                        averageLapTime =
                                            if List.isEmpty lapTimes then
                                                999999

                                            else
                                                List.sum lapTimes // List.length lapTimes

                                        carColor =
                                            generateCarColor car.metaData.carNumber
                                    in
                                    { carNumber = car.metaData.carNumber
                                    , laps = allLaps
                                    , color = carColor
                                    , averageLapTime = averageLapTime
                                    , totalLaps = List.length allLaps
                                    }
                                )
                            |> List.filter (\car -> car.totalLaps >= 2)
                            |> List.sortBy .averageLapTime

                    classAverageLapTime =
                        let
                            allAverages =
                                cars |> List.map .averageLapTime
                        in
                        if List.isEmpty allAverages then
                            999999

                        else
                            List.sum allAverages // List.length allAverages
                in
                { class = class
                , cars = cars
                , averageLapTime = classAverageLapTime
                , totalCars = List.length cars
                }
            )
        |> List.filter (\classData -> classData.totalCars > 0)
        |> List.sortBy .averageLapTime


extractLapDataForCar : Clock.Model -> ViewModelItem -> List Lap
extractLapDataForCar clock car =
    let
        currentRaceTime =
            Clock.getElapsed clock

        timeThreshold =
            currentRaceTime - (60 * 60 * 1000)
    in
    car.history
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


titleView : Html msg
titleView =
    h3
        [ css
            [ Css.fontSize (Css.rem 1.1)
            , Css.margin3 Css.zero Css.zero (Css.px 10)
            , Css.fontWeight Css.bold
            , Css.color (Css.hsl 0 0 0.9)
            , Css.letterSpacing (Css.px 0.5)
            ]
        ]
        [ text "Lap Time Progression" ]


separateClassChartsView : List ClassProgressionData -> Html msg
separateClassChartsView classDataList =
    if List.isEmpty classDataList then
        div
            [ css
                [ Css.fontStyle Css.italic
                , Css.color (Css.hsl 0 0 0.7)
                , Css.textAlign Css.center
                , Css.padding (Css.px 20)
                ]
            ]
            [ text "No lap progression data available" ]

    else
        div
            [ css
                [ Css.property "display" "grid"
                , Css.property "row-gap" "15px"
                ]
            ]
            (classDataList |> List.map singleClassProgressionChartView)


singleClassProgressionChartView : ClassProgressionData -> Html msg
singleClassProgressionChartView { class, cars, averageLapTime, totalCars } =
    if List.isEmpty cars then
        div [] []

    else
        div
            [ css
                [ Css.property "display" "grid"
                , Css.property "row-gap" "8px"
                ]
            ]
            [ div
                [ css
                    [ Css.displayFlex
                    , Css.justifyContent Css.spaceBetween
                    , Css.alignItems Css.center
                    ]
                ]
                [ div
                    [ css
                        [ Css.property "display" "grid"
                        , Css.property "grid-template-columns" "auto 1fr"
                        , Css.alignItems Css.center
                        , Css.property "column-gap" "5px"
                        , Css.fontSize (Css.px 14)
                        , Css.property "font-weight" "600"
                        , Css.color (Css.hsl 0 0 0.9)
                        , Css.before
                            [ Css.property "content" (Css.qt "")
                            , Css.display Css.block
                            , Css.width (Css.px 15)
                            , Css.height (Css.px 15)
                            , Css.backgroundColor (Class.toHexColor 2025 class)
                            , Css.borderRadius (Css.px 4)
                            ]
                        ]
                    ]
                    [ text (Class.toString class) ]
                , div [ css [ Css.fontSize (Css.rem 0.75), Css.color (Css.hsl 0 0 0.6) ] ]
                    [ text
                        (String.join " | "
                            [ "Avg: " ++ Duration.toString averageLapTime
                            , String.fromInt totalCars ++ " cars"
                            ]
                        )
                    ]
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
                    , Css.opacity (Css.num 0.7)
                    ]
                ]
                []
    in
    (fromUnstyled <|
        Path.element linePath
            [ TA.stroke (Paint carData.color)
            , TA.strokeWidth (Px 1.5)
            , TA.fill PaintNone
            , TA.strokeOpacity (Opacity 0.5)
            ]
    )
        :: points
