module Motorsport.Widget.LapTimeProgression exposing (view)

import Axis exposing (tickCount, tickFormat, tickSizeInner, tickSizeOuter)
import Color
import Css
import Css.Extra
import Css.Global exposing (descendants, each)
import Html.Styled as Html exposing (Html, div, h3, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.RaceControl.ViewModel exposing (ViewModel)
import Path
import Scale exposing (ContinuousScale)
import Shape
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, svg)
import Svg.Styled.Attributes as SvgAttr
import Time
import TypedSvg.Attributes as TA
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Length(..), Opacity(..), Paint(..), Transform(..))



-- Chart dimensions


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


type alias LapData =
    { carNumber : String
    , class : Class
    , lapTime : Duration
    , lapNumber : Int
    , timestamp : Time.Posix
    }


type alias CarProgressionData =
    { carNumber : String
    , class : Class
    , laps : List LapData
    , color : Color.Color
    , averageLapTime : Duration
    , totalLaps : Int
    }


type alias ClassProgressionData =
    { class : Class
    , cars : List CarProgressionData
    , classColor : Color.Color
    , averageLapTime : Duration
    , totalCars : Int
    }


view : Analysis -> ViewModel -> Html msg
view analysis viewModel =
    let
        classDataList =
            processClassProgressionData viewModel
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


extractLapProgressionData : ViewModel -> List LapData
extractLapProgressionData viewModel =
    let
        -- Find the latest elapsed time across all cars to determine current race time
        currentRaceTime =
            viewModel
                |> List.filterMap (\car -> car.history |> List.map .elapsed |> List.maximum)
                |> List.maximum
                |> Maybe.withDefault 0

        -- Only show data from the last hour
        timeThreshold =
            currentRaceTime - (60 * 60 * 1000)
    in
    viewModel
        |> List.concatMap
            (\car ->
                car.history
                    |> List.filter (\lap -> lap.elapsed >= timeThreshold)
                    |> List.map
                        (\lap ->
                            { carNumber = car.metaData.carNumber
                            , class = car.metaData.class
                            , lapTime = lap.time
                            , lapNumber = lap.lap
                            , timestamp = Time.millisToPosix lap.elapsed
                            }
                        )
            )
        |> List.filter (\lap -> lap.lapTime > 0 && lap.lapTime < 999999)


processClassProgressionData : ViewModel -> List ClassProgressionData
processClassProgressionData viewModel =
    let
        allLapData =
            extractLapProgressionData viewModel
    in
    allLapData
        |> List.Extra.gatherEqualsBy .class
        |> List.map (\( first, rest ) -> ( first.class, first :: rest ))
        |> List.map
            (\( class, classLaps ) ->
                let
                    carGroups =
                        classLaps
                            |> List.Extra.gatherEqualsBy .carNumber
                            |> List.map (\( first, rest ) -> ( first.carNumber, first :: rest ))

                    cars =
                        carGroups
                            |> List.map
                                (\( carNumber, laps ) ->
                                    let
                                        -- Keep all laps (including pit stops) for display
                                        allLaps =
                                            laps

                                        -- For statistics, still filter outliers
                                        normalLaps =
                                            filterOutlierLaps laps

                                        lapTimes =
                                            List.map .lapTime normalLaps

                                        averageLapTime =
                                            if List.isEmpty lapTimes then
                                                999999

                                            else
                                                List.sum lapTimes // List.length lapTimes

                                        carColor =
                                            generateCarColor carNumber class
                                    in
                                    { carNumber = carNumber
                                    , class = class
                                    , laps = allLaps
                                    , color = carColor
                                    , averageLapTime = averageLapTime
                                    , totalLaps = List.length allLaps
                                    }
                                )
                            |> List.filter (\car -> car.totalLaps >= 3)
                            -- Only show cars with at least 3 laps
                            |> List.sortBy .averageLapTime

                    classColor =
                        getClassColor class

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
                , classColor = classColor
                , averageLapTime = classAverageLapTime
                , totalCars = List.length cars
                }
            )
        |> List.filter (\classData -> classData.totalCars > 0)
        |> List.sortBy .averageLapTime


filterOutlierLaps : List LapData -> List LapData
filterOutlierLaps laps =
    case laps of
        [] ->
            []

        _ ->
            let
                lapTimes =
                    List.map .lapTime laps

                fastestTime =
                    List.minimum lapTimes |> Maybe.withDefault 999999

                -- Allow laps within 115% of fastest lap (more lenient for progression analysis)
                threshold =
                    toFloat fastestTime * 1.1 |> round
            in
            laps
                |> List.filter (\lap -> lap.lapTime <= threshold)


generateCarColor : String -> Class -> Color.Color
generateCarColor carNumber class =
    let
        -- Generate a color based on car number and class
        carHash =
            String.toInt carNumber |> Maybe.withDefault 0

        classColor =
            getClassColor class

        classRgba =
            Color.toRgba classColor

        -- Create variations of the class color
        hue =
            carHash * 37 |> modBy 360 |> toFloat

        saturation =
            0.7 + (toFloat (carHash * 17 |> modBy 30) / 100)

        lightness =
            0.5 + (toFloat (carHash * 13 |> modBy 20) / 100)
    in
    Color.hsl (hue / 360) saturation lightness


getClassColor : Class -> Color.Color
getClassColor class =
    let
        classString =
            Class.toString class
    in
    case classString of
        "None" ->
            Color.rgb255 128 128 128

        "HYPERCAR" ->
            Color.rgb255 255 0 0

        "LMP1" ->
            Color.rgb255 255 0 0

        "LMP2" ->
            Color.rgb255 0 0 255

        "LMGTE Pro" ->
            Color.rgb255 0 102 0

        "LMGTE Am" ->
            Color.rgb255 255 102 0

        "LMGT3" ->
            Color.rgb255 255 102 0

        "INNOVATIVE CAR" ->
            Color.rgb255 0 0 255

        _ ->
            Color.rgb255 128 128 128


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
                [ Css.property "display" "flex"
                , Css.property "flex-direction" "column"
                , Css.property "gap" "20px"
                ]
            ]
            (classDataList |> List.map singleClassProgressionChartView)


singleClassProgressionChartView : ClassProgressionData -> Html msg
singleClassProgressionChartView classData =
    if List.isEmpty classData.cars then
        div [] []

    else
        div
            [ css
                [ Css.property "display" "flex"
                , Css.property "flex-direction" "column"
                , Css.property "gap" "8px"
                ]
            ]
            [ -- Class header
              div
                [ css
                    [ Css.property "display" "flex"
                    , Css.property "justify-content" "space-between"
                    , Css.property "align-items" "center"
                    ]
                ]
                [ div
                    [ css
                        [ Css.property "display" "flex"
                        , Css.property "align-items" "center"
                        , Css.property "column-gap" "5px"
                        ]
                    ]
                    [ div
                        [ css
                            [ Css.width (Css.px 15)
                            , Css.height (Css.px 15)
                            , Css.backgroundColor (Class.toHexColor 2025 classData.class)
                            , Css.borderRadius (Css.px 4)
                            ]
                        ]
                        []
                    , div
                        [ css
                            [ Css.fontSize (Css.px 14)
                            , Css.property "font-weight" "600"
                            , Css.color (Css.hsl 0 0 0.9)
                            ]
                        ]
                        [ text (Class.toString classData.class) ]
                    ]
                , div
                    [ css
                        [ Css.fontSize (Css.rem 0.75)
                        , Css.color (Css.hsl 0 0 0.6)
                        ]
                    ]
                    [ text
                        ("Avg: "
                            ++ Duration.toString classData.averageLapTime
                            ++ " | "
                            ++ String.fromInt classData.totalCars
                            ++ " cars"
                        )
                    ]
                ]
            , -- Chart
              svg
                [ InPx.width w
                , InPx.height h
                , viewBox 0 0 w h
                , SvgAttr.css [ Css.display Css.block ]
                ]
                ([ xAxisSingle classData
                 , yAxisSingle classData
                 ]
                    ++ renderClassProgressionLines classData
                )
            ]



-- Scales for individual class charts


xScaleSingle : ClassProgressionData -> ContinuousScale Float
xScaleSingle classData =
    let
        allElapsedTimes =
            classData.cars
                |> List.concatMap (.laps >> List.map (.timestamp >> Time.posixToMillis))
                |> List.map toFloat

        minTime =
            List.minimum allElapsedTimes |> Maybe.withDefault 0

        maxTime =
            List.maximum allElapsedTimes |> Maybe.withDefault 0
    in
    Scale.linear ( paddingLeft, w - padding ) ( minTime, maxTime )


yScaleSingle : ClassProgressionData -> ContinuousScale Float
yScaleSingle classData =
    let
        -- For y-scale calculation, filter out extreme outliers to keep chart readable
        normalLapTimes =
            classData.cars
                |> List.concatMap .laps
                |> filterOutlierLaps
                |> List.map (.lapTime >> toFloat)

        minTime =
            List.minimum normalLapTimes |> Maybe.withDefault 0

        maxTime =
            List.maximum normalLapTimes |> Maybe.withDefault 0

        -- Add some padding to the y-axis
        padding_y =
            (maxTime - minTime) * 0.1

        adjustedMin =
            minTime - padding_y

        adjustedMax =
            maxTime + padding_y
    in
    Scale.linear ( h - paddingBottom, padding ) ( adjustedMin, adjustedMax )



-- Axes


xAxisSingle : ClassProgressionData -> Svg msg
xAxisSingle classData =
    let
        axis =
            fromUnstyled <|
                Axis.bottom
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 3
                    , tickFormat (\f -> Duration.toString (round f))
                    ]
                    (xScaleSingle classData)
    in
    g
        [ SvgAttr.css
            [ descendants
                [ Css.Global.typeSelector "text"
                    [ Css.fill (Css.hsl 0 0 0.7)
                    , Css.fontSize (Css.px 9)
                    ]
                , Css.Global.typeSelector "line"
                    [ Css.property "stroke" "#666"
                    , Css.property "stroke-width" "0.5"
                    ]
                , Css.Global.typeSelector "path" [ Css.display Css.none ]
                ]
            ]
        , transform [ Translate 0 (h - paddingBottom) ]
        ]
        [ axis ]


yAxisSingle : ClassProgressionData -> Svg msg
yAxisSingle classData =
    let
        axis =
            fromUnstyled <|
                Axis.left
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 5
                    , tickFormat (\f -> Duration.toString (round f))
                    ]
                    (yScaleSingle classData)
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
                    , Css.property "stroke" "#444"
                    ]
                ]
            ]
        , transform [ Translate paddingLeft 0 ]
        ]
        [ axis ]



-- Line rendering


renderClassProgressionLines : ClassProgressionData -> List (Svg msg)
renderClassProgressionLines classData =
    classData.cars
        |> List.concatMap (renderCarProgressionLine classData)


renderCarProgressionLine : ClassProgressionData -> CarProgressionData -> List (Svg msg)
renderCarProgressionLine classData carData =
    let
        dataPoints =
            carData.laps
                |> List.map (\lap -> ( toFloat (Time.posixToMillis lap.timestamp), toFloat lap.lapTime ))

        linePath =
            dataPoints
                |> List.map
                    (\( x, y ) ->
                        Just
                            ( Scale.convert (xScaleSingle classData) x
                            , Scale.convert (yScaleSingle classData) y
                            )
                    )
                |> Shape.line Shape.linearCurve

        points =
            dataPoints
                |> List.map
                    (\( x, y ) ->
                        circle
                            [ InPx.cx (Scale.convert (xScaleSingle classData) x)
                            , InPx.cy (Scale.convert (yScaleSingle classData) y)
                            , InPx.r 2
                            , SvgAttr.css
                                [ Css.fill (colorToCss carData.color)
                                , Css.property "stroke" "none"
                                , Css.opacity (Css.num 0.7)
                                ]
                            ]
                            []
                    )
    in
    [ -- Car progression line
      fromUnstyled <|
        Path.element linePath
            [ TA.stroke (Paint carData.color)
            , TA.strokeWidth (Px 1.5)
            , TA.fill PaintNone
            , TA.strokeOpacity (Opacity 0.5)
            ]
    ]
        ++ points
