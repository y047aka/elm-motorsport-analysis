module Motorsport.Chart.BoxPlot exposing (view)

import Axis exposing (tickCount, tickFormat, tickSizeInner, tickSizeOuter)
import Css exposing (Color, height, width)
import Css.Extra
import Css.Global exposing (descendants, each)
import Html.Styled exposing (Html)
import List.Extra as ListExtra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Duration as Duration
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance
import Motorsport.Manufacturer as Manufacturer
import Motorsport.RaceControl.ViewModel exposing (ViewModelItem)
import Scale exposing (BandScale, ContinuousScale)
import Statistics
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, line, rect, svg)
import Svg.Styled.Attributes as SvgAttributes
import TypedSvg.Styled.Attributes as TypedSvgAttributes
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Transform(..), px)


chartWidth : Float
chartWidth =
    300


chartHeight : Float
chartHeight =
    180


padding : Float
padding =
    15


paddingLeft : Float
paddingLeft =
    padding + 35


paddingBottom : Float
paddingBottom =
    padding + 20


type alias BoxStats =
    { firstQuartile : Float
    , median : Float
    , thirdQuartile : Float
    , max : Float
    , min : Float
    , outliers : List Float
    }


xScale : List String -> BandScale String
xScale carNumbers =
    Scale.band
        { defaultBandConfig | paddingInner = 0.2, paddingOuter = 0.1 }
        ( paddingLeft, chartWidth - padding )
        carNumbers


defaultBandConfig : Scale.BandConfig
defaultBandConfig =
    { paddingInner = 0
    , paddingOuter = 0
    , align = 0.5
    }


type alias CarBoxPlot =
    { carNumber : String
    , stats : BoxStats
    , color : Color
    , currentLap : Maybe Lap
    }


view : Analysis -> List ViewModelItem -> Html msg
view analysis selectedCars =
    let
        carBoxPlots =
            selectedCars
                |> List.map
                    (\item ->
                        { carNumber = item.metadata.carNumber
                        , stats = computeStatistics item.history
                        , color = Manufacturer.toColorWithFallback item.metadata
                        , currentLap = item.currentLap
                        }
                    )

        carNumbers =
            selectedCars |> List.map (.metadata >> .carNumber)

        yScale_ =
            computeGlobalYScale analysis carBoxPlots

        xScale_ =
            xScale carNumbers
    in
    svg
        [ TypedSvgAttributes.viewBox 0 0 chartWidth chartHeight
        , SvgAttributes.css [ width (Css.px chartWidth), height (Css.px chartHeight) ]
        ]
        [ yAxis yScale_
        , xAxis xScale_
        , g []
            (carBoxPlots |> List.map (renderCarBoxPlot xScale_ yScale_ analysis))
        ]


xAxis : BandScale String -> Svg msg
xAxis scale =
    let
        axis =
            fromUnstyled <|
                Axis.bottom
                    [ tickSizeOuter 0
                    , tickSizeInner 3
                    ]
                    (Scale.toRenderable identity scale)
    in
    g
        [ TypedSvgAttributes.transform [ Translate 0 (chartHeight - paddingBottom) ]
        , SvgAttributes.css
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
        ]
        [ axis ]


yAxis : ContinuousScale Float -> Svg msg
yAxis scale =
    let
        axis =
            fromUnstyled <|
                Axis.left
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 3
                    , tickFormat (round >> Duration.toString)
                    ]
                    scale
    in
    g
        [ TypedSvgAttributes.transform [ Translate paddingLeft 0 ]
        , SvgAttributes.css
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
        ]
        [ axis ]


computeStatistics : List Lap -> BoxStats
computeStatistics laps =
    let
        sortedTimes =
            laps
                |> List.map (.time >> toFloat)
                |> List.filter (\value -> value > 0)
                |> List.sort

        lastValue =
            sortedTimes |> ListExtra.last |> Maybe.withDefault 0

        firstQuartile =
            Statistics.quantile 0.25 sortedTimes
                |> Maybe.withDefault 0

        thirdQuartile =
            Statistics.quantile 0.75 sortedTimes
                |> Maybe.withDefault lastValue

        median =
            Statistics.quantile 0.5 sortedTimes
                |> Maybe.withDefault firstQuartile

        interQuartileRange =
            thirdQuartile - firstQuartile

        whiskerTopMax =
            thirdQuartile + (1.5 * interQuartileRange)

        whiskerBottomMin =
            firstQuartile - (1.5 * interQuartileRange)

        isOutlier value =
            value < whiskerBottomMin || value > whiskerTopMax

        nonOutliers =
            sortedTimes |> List.filter (isOutlier >> not)

        lowerWhisker =
            nonOutliers |> List.head |> Maybe.withDefault 0

        upperWhisker =
            nonOutliers |> ListExtra.last |> Maybe.withDefault lastValue

        outliers =
            sortedTimes |> List.filter isOutlier
    in
    { firstQuartile = firstQuartile
    , median = median
    , thirdQuartile = thirdQuartile
    , max = upperWhisker
    , min = lowerWhisker
    , outliers = outliers
    }


computeGlobalYScale : Analysis -> List CarBoxPlot -> ContinuousScale Float
computeGlobalYScale { fastestLapTime, slowestLapTime } carBoxPlots =
    let
        allValues =
            carBoxPlots
                |> List.concatMap (\car -> [ car.stats.min, car.stats.max ])

        minValue =
            allValues
                |> List.minimum
                |> Maybe.withDefault (toFloat fastestLapTime)
                |> min (toFloat fastestLapTime)

        maxValue =
            allValues
                |> List.maximum
                |> Maybe.withDefault (toFloat slowestLapTime)
                |> max (toFloat fastestLapTime * 1.07)
    in
    Scale.linear ( chartHeight - paddingBottom, padding ) ( minValue, maxValue )


renderCarBoxPlot : BandScale String -> ContinuousScale Float -> Analysis -> CarBoxPlot -> Svg msg
renderCarBoxPlot xScale_ yScale_ analysis { carNumber, stats, color, currentLap } =
    let
        xPosition =
            Scale.convert xScale_ carNumber

        bandwidth =
            Scale.bandwidth xScale_

        left =
            xPosition

        center =
            left + (bandwidth / 2)

        firstQuartileY =
            Scale.convert yScale_ stats.firstQuartile

        thirdQuartileY =
            Scale.convert yScale_ stats.thirdQuartile

        boxTop =
            Basics.min firstQuartileY thirdQuartileY

        boxBottom =
            Basics.max firstQuartileY thirdQuartileY

        outlierDots =
            stats.outliers
                |> List.map (Scale.convert yScale_ >> outlierCircle "#c44b4b" center)

        colorForCurrent lap =
            { time = lap.time
            , personalBest = stats.min |> round
            , fastest = analysis.fastestLapTime
            }
                |> Performance.performanceLevel
                |> Performance.toColorVariable

        currentLapMarker =
            currentLap
                |> Maybe.map (\lap -> currentLapCircle (colorForCurrent lap) yScale_ center lap)
                |> Maybe.map List.singleton
                |> Maybe.withDefault []
    in
    g []
        ([ whisker
            { color = color
            , center = center
            , width = bandwidth * 0.3
            , upperWhiskerY = Scale.convert yScale_ stats.max
            , boxTop = boxTop
            , boxBottom = boxBottom
            , lowerWhiskerY = Scale.convert yScale_ stats.min
            }
         , box
            { top = boxTop
            , left = left
            , width = bandwidth
            , height = Basics.max 1 (boxBottom - boxTop)
            , color = color
            }
         , medianLine
            { left = left
            , width = bandwidth
            , medianY = Scale.convert yScale_ stats.median
            , color = color
            }
         ]
            ++ outlierDots
            ++ currentLapMarker
        )


box :
    { top : Float
    , left : Float
    , width : Float
    , height : Float
    , color : Color
    }
    -> Svg msg
box { top, left, width, height, color } =
    rect
        [ InPx.x left
        , InPx.y top
        , InPx.width width
        , InPx.height height
        , SvgAttributes.css [ Css.opacity (Css.num 0.5) ]
        , SvgAttributes.fill color.value
        , SvgAttributes.stroke "#2e2e2e"
        , SvgAttributes.strokeWidth "1"
        ]
        []


whisker :
    { color : Color
    , center : Float
    , width : Float
    , upperWhiskerY : Float
    , boxTop : Float
    , boxBottom : Float
    , lowerWhiskerY : Float
    }
    -> Svg msg
whisker { color, center, width, upperWhiskerY, boxTop, boxBottom, lowerWhiskerY } =
    g
        [ SvgAttributes.strokeWidth "1"
        , SvgAttributes.stroke color.value
        ]
        [ line
            [ TypedSvgAttributes.x1 (px center)
            , TypedSvgAttributes.y1 (px upperWhiskerY)
            , TypedSvgAttributes.x2 (px center)
            , TypedSvgAttributes.y2 (px boxTop)
            ]
            []
        , line
            [ TypedSvgAttributes.x1 (px (center - width / 2))
            , TypedSvgAttributes.y1 (px upperWhiskerY)
            , TypedSvgAttributes.x2 (px (center + width / 2))
            , TypedSvgAttributes.y2 (px upperWhiskerY)
            ]
            []
        , line
            [ TypedSvgAttributes.x1 (px center)
            , TypedSvgAttributes.y1 (px boxBottom)
            , TypedSvgAttributes.x2 (px center)
            , TypedSvgAttributes.y2 (px lowerWhiskerY)
            ]
            []
        , line
            [ TypedSvgAttributes.x1 (px (center - width / 2))
            , TypedSvgAttributes.y1 (px lowerWhiskerY)
            , TypedSvgAttributes.x2 (px (center + width / 2))
            , TypedSvgAttributes.y2 (px lowerWhiskerY)
            ]
            []
        ]


medianLine :
    { left : Float
    , width : Float
    , medianY : Float
    , color : Color
    }
    -> Svg msg
medianLine { left, width, medianY, color } =
    line
        [ TypedSvgAttributes.x1 (px left)
        , TypedSvgAttributes.y1 (px medianY)
        , TypedSvgAttributes.x2 (px (left + width))
        , TypedSvgAttributes.y2 (px medianY)
        , SvgAttributes.strokeWidth "1"
        , SvgAttributes.stroke color.value
        ]
        []


outlierCircle : String -> Float -> Float -> Svg msg
outlierCircle color x y =
    circle
        [ InPx.cx x
        , InPx.cy y
        , InPx.r 2
        , SvgAttributes.fill color
        ]
        []


currentLapCircle : String -> ContinuousScale Float -> Float -> Lap -> Svg msg
currentLapCircle color yScale_ center lap =
    circle
        [ InPx.cx center
        , InPx.cy (Scale.convert yScale_ (toFloat lap.time))
        , InPx.r 2.5
        , SvgAttributes.fill color
        , SvgAttributes.strokeWidth "0.6"
        ]
        []
