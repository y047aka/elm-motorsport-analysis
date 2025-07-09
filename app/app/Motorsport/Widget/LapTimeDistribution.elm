module Motorsport.Widget.LapTimeDistribution exposing (view)

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
import Path exposing (Path)
import Scale exposing (ContinuousScale)
import Shape
import Svg.Styled exposing (Svg, fromUnstyled, g, svg)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Attributes as TA
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Length(..), Paint(..), Transform(..))



-- Chart dimensions


w : Float
w =
    320


h : Float
h =
    150


padding : Float
padding =
    15


paddingLeft : Float
paddingLeft =
    padding + 10


paddingBottom : Float
paddingBottom =
    padding + 10


type alias LapTimeData =
    { carNumber : String
    , class : Class
    , lapTime : Duration
    }


type alias DataPoint =
    ( Duration, Float )


type alias ClassData =
    { class : Class
    , dataPoints : List DataPoint
    , color : Color.Color
    , totalLaps : Int
    , filteredLaps : Int
    , fastestLap : Duration
    , threshold : Duration
    }


type alias HistogramBin =
    { timeRange : String
    , minTime : Duration
    , maxTime : Duration
    , cars : List LapTimeData
    , count : Int
    , density : Float
    }


view : Analysis -> ViewModel -> Html msg
view analysis viewModel =
    let
        classDataList =
            processClassData viewModel
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


extractLapTimeData : ViewModel -> List LapTimeData
extractLapTimeData viewModel =
    viewModel
        |> List.filterMap
            (\car ->
                car.lastLap
                    |> Maybe.map
                        (\lap ->
                            { carNumber = car.metaData.carNumber
                            , class = car.metaData.class
                            , lapTime = lap.time
                            }
                        )
            )
        |> List.sortBy .lapTime


createHistogram : List LapTimeData -> Int -> List HistogramBin
createHistogram lapTimeData binCount =
    case lapTimeData of
        [] ->
            []

        data ->
            let
                times =
                    List.map .lapTime data

                minTime =
                    List.minimum times |> Maybe.withDefault 0

                maxTime =
                    List.maximum times |> Maybe.withDefault 0

                binWidth =
                    if minTime == maxTime then
                        500
                        -- Smaller bin width for more granularity

                    else
                        (maxTime - minTime) // binCount

                totalCars =
                    List.length data

                bins =
                    List.range 0 (binCount - 1)
                        |> List.map
                            (\i ->
                                let
                                    binMin =
                                        minTime + (i * binWidth)

                                    binMax =
                                        if i == binCount - 1 then
                                            maxTime

                                        else
                                            binMin + binWidth - 1

                                    carsInBin =
                                        data
                                            |> List.filter
                                                (\car ->
                                                    car.lapTime >= binMin && car.lapTime <= binMax
                                                )

                                    count =
                                        List.length carsInBin

                                    density =
                                        if totalCars > 0 then
                                            toFloat count / toFloat totalCars

                                        else
                                            0

                                    timeRange =
                                        formatTimeRange binMin binMax
                                in
                                { timeRange = timeRange
                                , minTime = binMin
                                , maxTime = binMax
                                , cars = carsInBin
                                , count = count
                                , density = density
                                }
                            )
            in
            bins


formatTimeRange : Duration -> Duration -> String
formatTimeRange minTime maxTime =
    let
        minStr =
            Duration.toString minTime

        maxStr =
            Duration.toString maxTime

        diffMs =
            maxTime - minTime
    in
    if diffMs < 1000 then
        -- Show milliseconds for very fine ranges
        minStr ++ "-" ++ maxStr

    else
        -- Show only start time for larger ranges
        minStr


histogramToDataPoints : List HistogramBin -> List DataPoint
histogramToDataPoints bins =
    bins
        |> List.map (\bin -> ( bin.minTime, toFloat bin.count ))
        |> List.sortBy Tuple.first


type alias FilterResult =
    { filteredCars : List LapTimeData
    , fastestLap : Duration
    , threshold : Duration
    }


filterOutliersWithInfo : List LapTimeData -> FilterResult
filterOutliersWithInfo cars =
    case cars of
        [] ->
            { filteredCars = []
            , fastestLap = 999999
            , threshold = 999999
            }

        _ ->
            let
                -- Find the fastest lap time in this class
                fastestTime =
                    cars
                        |> List.map .lapTime
                        |> List.minimum
                        |> Maybe.withDefault 999999

                -- Calculate 110% threshold (allowing 10% slower than fastest)
                threshold =
                    toFloat fastestTime * 1.1 |> round

                -- Filter out laps slower than 110% of fastest lap
                filteredCars =
                    cars
                        |> List.filter (\car -> car.lapTime <= threshold)
            in
            { filteredCars = filteredCars
            , fastestLap = fastestTime
            , threshold = threshold
            }


processClassData : ViewModel -> List ClassData
processClassData viewModel =
    let
        lapTimeData =
            extractLapTimeData viewModel
    in
    lapTimeData
        |> List.Extra.gatherEqualsBy .class
        |> List.map (\( first, rest ) -> ( first.class, first :: rest ))
        |> List.map
            (\( class, cars ) ->
                let
                    totalLaps =
                        List.length cars

                    -- Filter out outliers (pit stops, troubles) - keep only laps within 110% of fastest lap
                    filterResult =
                        filterOutliersWithInfo cars

                    filteredLaps =
                        List.length filterResult.filteredCars

                    histogram =
                        createHistogram filterResult.filteredCars 10

                    dataPoints =
                        histogramToDataPoints histogram

                    classColor =
                        getClassColor class
                in
                { class = class
                , dataPoints = dataPoints
                , color = classColor
                , totalLaps = totalLaps
                , filteredLaps = filteredLaps
                , fastestLap = filterResult.fastestLap
                , threshold = filterResult.threshold
                }
            )


getClassColor : Class -> Color.Color
getClassColor class =
    let
        classString =
            Class.toString class
    in
    case classString of
        "None" ->
            Color.rgb255 128 128 128

        -- Gray
        "HYPERCAR" ->
            Color.rgb255 255 0 0

        -- Red
        "LMP1" ->
            Color.rgb255 255 0 0

        -- Red
        "LMP2" ->
            Color.rgb255 0 0 255

        -- Blue
        "LMGTE Pro" ->
            Color.rgb255 0 102 0

        -- Green
        "LMGTE Am" ->
            Color.rgb255 255 102 0

        -- Orange
        "LMGT3" ->
            Color.rgb255 255 102 0

        -- Orange
        "INNOVATIVE CAR" ->
            Color.rgb255 0 0 255

        -- Blue
        _ ->
            Color.rgb255 128 128 128



-- Default Gray


formatFilterInfo : ClassData -> String
formatFilterInfo classData =
    let
        excludedLaps =
            classData.totalLaps - classData.filteredLaps

        excludedPercentage =
            if classData.totalLaps > 0 then
                toFloat excludedLaps / toFloat classData.totalLaps * 100

            else
                0
    in
    let
        fastestLapStr =
            Duration.toString classData.fastestLap

        thresholdStr =
            Duration.toString classData.threshold
    in
    if excludedLaps > 0 then
        String.fromInt classData.filteredLaps
            ++ " laps ("
            ++ String.fromInt excludedLaps
            ++ " outliers >"
            ++ thresholdStr
            ++ " excluded, "
            ++ String.fromFloat (toFloat (round (excludedPercentage * 10)) / 10)
            ++ "%) | Fastest: "
            ++ fastestLapStr

    else
        String.fromInt classData.filteredLaps ++ " laps | Fastest: " ++ fastestLapStr


colorToCss : Color.Color -> Css.Color
colorToCss color =
    let
        rgba =
            Color.toRgba color
    in
    Css.rgba (round (rgba.red * 255)) (round (rgba.green * 255)) (round (rgba.blue * 255)) rgba.alpha


renderClassLine : List ClassData -> ClassData -> List (Svg msg)
renderClassLine allClassData classData =
    if List.isEmpty classData.dataPoints then
        []

    else
        [ -- Area fill under the line with low opacity
          fromUnstyled <|
            Path.element (area allClassData classData.dataPoints)
                [ TA.fill (Paint (Color.toRgba classData.color |> (\rgba -> Color.rgba rgba.red rgba.green rgba.blue 0.2)))
                ]
        , -- Main line
          fromUnstyled <|
            Path.element (line allClassData classData.dataPoints)
                [ TA.stroke (Paint classData.color)
                , TA.strokeWidth (Px 2)
                , TA.fill PaintNone
                ]
        ]


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
        [ text "Lap Time Distribution" ]



-- Scales


xScale : List ClassData -> ContinuousScale Float
xScale classDataList =
    let
        allDataPoints =
            classDataList |> List.concatMap .dataPoints

        times =
            List.map (Tuple.first >> toFloat) allDataPoints

        minTime =
            List.minimum times |> Maybe.withDefault 0

        maxTime =
            List.maximum times |> Maybe.withDefault 0
    in
    Scale.linear ( paddingLeft, w - padding ) ( minTime, maxTime )


yScale : List ClassData -> ContinuousScale Float
yScale classDataList =
    let
        allDataPoints =
            classDataList |> List.concatMap .dataPoints

        maxCount =
            allDataPoints |> List.map Tuple.second |> List.maximum |> Maybe.withDefault 1
    in
    Scale.linear ( h - paddingBottom, padding ) ( 0, maxCount )



-- Line generation


line : List ClassData -> List DataPoint -> Path
line classDataList dataPoints =
    dataPoints
        |> List.map (\( x, y ) -> Just ( Scale.convert (xScale classDataList) (toFloat x), Scale.convert (yScale classDataList) y ))
        |> Shape.line Shape.monotoneInXCurve


area : List ClassData -> List DataPoint -> Path
area classDataList dataPoints =
    dataPoints
        |> List.map
            (\( x, y ) ->
                Just
                    ( ( Scale.convert (xScale classDataList) (toFloat x), Tuple.first (Scale.rangeExtent (yScale classDataList)) )
                    , ( Scale.convert (xScale classDataList) (toFloat x), Scale.convert (yScale classDataList) y )
                    )
            )
        |> Shape.area Shape.linearCurve



-- Axes


xAxis : List ClassData -> Svg msg
xAxis classDataList =
    let
        axis =
            fromUnstyled <|
                Axis.bottom
                    [ tickCount 6
                    , tickSizeOuter 0
                    , tickSizeInner 3
                    , tickFormat (\f -> Duration.toString (round f))
                    ]
                    (xScale classDataList)
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


yAxis : List ClassData -> Svg msg
yAxis classDataList =
    let
        axis =
            fromUnstyled <|
                Axis.left [ tickCount 5, tickSizeOuter 0, tickSizeInner 5 ] (yScale classDataList)
    in
    g
        [ SvgAttr.css
            [ descendants
                [ Css.Global.typeSelector "text"
                    [ Css.fill (Css.hsl 0 0 0.7)
                    , Css.fontSize (Css.px 10)
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



-- Chart view


separateClassChartsView : List ClassData -> Html msg
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
            [ text "No lap time data available" ]

    else
        div
            [ css
                [ Css.property "display" "flex"
                , Css.property "flex-direction" "column"
                , Css.property "gap" "15px"
                ]
            ]
            (classDataList |> List.map singleClassChartView)


singleClassChartView : ClassData -> Html msg
singleClassChartView classData =
    if List.isEmpty classData.dataPoints then
        div [] []

    else
        div
            [ css
                [ Css.property "display" "flex"
                , Css.property "flex-direction" "column"
                , Css.property "gap" "5px"
                ]
            ]
            [ -- Class title
              div
                [ css
                    [ Css.fontSize (Css.rem 0.9)
                    , Css.fontWeight Css.bold
                    , Css.color (colorToCss classData.color)
                    , Css.textAlign Css.center
                    ]
                ]
                [ text (Class.toString classData.class) ]
            , -- Filter info
              div
                [ css
                    [ Css.fontSize (Css.rem 0.7)
                    , Css.color (Css.hsl 0 0 0.6)
                    , Css.textAlign Css.center
                    , Css.marginBottom (Css.px 5)
                    ]
                ]
                [ text (formatFilterInfo classData) ]
            , -- Chart
              svg
                [ InPx.width w
                , InPx.height (h * 0.6) -- Compact height for individual charts
                , viewBox 0 0 w (h * 0.6)
                , SvgAttr.css [ Css.display Css.block ]
                ]
                [ xAxisSingle classData
                , yAxisSingle classData
                , renderSingleClassLine classData
                ]
            ]



-- Individual class chart functions


xScaleSingle : ClassData -> ContinuousScale Float
xScaleSingle classData =
    let
        times =
            List.map (Tuple.first >> toFloat) classData.dataPoints

        minTime =
            List.minimum times |> Maybe.withDefault 0

        maxTime =
            List.maximum times |> Maybe.withDefault 0
    in
    Scale.linear ( paddingLeft, w - padding ) ( minTime, maxTime )


yScaleSingle : ClassData -> ContinuousScale Float
yScaleSingle classData =
    let
        maxCount =
            classData.dataPoints |> List.map Tuple.second |> List.maximum |> Maybe.withDefault 1
    in
    Scale.linear ( (h * 0.6) - paddingBottom, padding ) ( 0, maxCount )


xAxisSingle : ClassData -> Svg msg
xAxisSingle classData =
    let
        axis =
            fromUnstyled <|
                Axis.bottom
                    [ tickCount 6
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
        , transform [ Translate 0 ((h * 0.6) - paddingBottom) ]
        ]
        [ axis ]


yAxisSingle : ClassData -> Svg msg
yAxisSingle classData =
    let
        axis =
            fromUnstyled <|
                Axis.left [ tickCount 4, tickSizeOuter 0, tickSizeInner 5 ] (yScaleSingle classData)
    in
    g
        [ SvgAttr.css
            [ descendants
                [ Css.Global.typeSelector "text"
                    [ Css.fill (Css.hsl 0 0 0.7)
                    , Css.fontSize (Css.px 10)
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


lineSingle : ClassData -> Path
lineSingle classData =
    classData.dataPoints
        |> List.map (\( x, y ) -> Just ( Scale.convert (xScaleSingle classData) (toFloat x), Scale.convert (yScaleSingle classData) y ))
        |> Shape.line Shape.monotoneInXCurve


areaSingle : ClassData -> Path
areaSingle classData =
    classData.dataPoints
        |> List.map
            (\( x, y ) ->
                Just
                    ( ( Scale.convert (xScaleSingle classData) (toFloat x), Tuple.first (Scale.rangeExtent (yScaleSingle classData)) )
                    , ( Scale.convert (xScaleSingle classData) (toFloat x), Scale.convert (yScaleSingle classData) y )
                    )
            )
        |> Shape.area Shape.linearCurve


renderSingleClassLine : ClassData -> Svg msg
renderSingleClassLine classData =
    g []
        [ -- Area fill under the line with low opacity
          fromUnstyled <|
            Path.element (areaSingle classData)
                [ TA.fill (Paint (Color.toRgba classData.color |> (\rgba -> Color.rgba rgba.red rgba.green rgba.blue 0.2)))
                ]
        , -- Main line
          fromUnstyled <|
            Path.element (lineSingle classData)
                [ TA.stroke (Paint classData.color)
                , TA.strokeWidth (Px 2)
                , TA.fill PaintNone
                ]
        ]
