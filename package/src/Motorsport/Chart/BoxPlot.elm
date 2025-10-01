module Motorsport.Chart.BoxPlot exposing (view)

import Axis exposing (tickCount, tickFormat, tickSizeInner, tickSizeOuter)
import Css exposing (height, width)
import Css.Extra
import Css.Global exposing (descendants, each)
import Dict exposing (Dict)
import Html.Styled exposing (Html)
import List.Extra as ListExtra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (performanceLevel)
import Scale exposing (ContinuousScale)
import Statistics
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, line, rect, svg)
import Svg.Styled.Attributes as SvgAttributes
import TypedSvg.Styled.Attributes as TypedSvgAttributes
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Transform(..), px)


chartWidth : Float
chartWidth =
    220


chartHeight : Float
chartHeight =
    100


segmentWidthFor : Int -> Float
segmentWidthFor stintCount =
    let
        actualCount =
            Basics.max 1 stintCount

        totalGapWidth =
            gapsWidthFor stintCount

        availableWidth =
            chartWidth - (axisOffset + padding) - padding - totalGapWidth
    in
    if availableWidth <= 0 then
        0

    else
        availableWidth / toFloat actualCount


segmentGap : Float
segmentGap =
    6


axisOffset : Float
axisOffset =
    50


padding : Float
padding =
    1


type alias HistogramStint =
    { driver : Driver
    , stintNumber : Int
    , laps : List Lap
    }


type alias BoxStats =
    { firstQuartile : Float
    , median : Float
    , thirdQuartile : Float
    , max : Float
    , min : Float
    , outliers : List Float
    }


yScale : ( Float, Float ) -> ContinuousScale Float
yScale ( min, max ) =
    ( min, max ) |> Scale.linear ( chartHeight - padding, padding )


xScale : { stintCount : Int, segmentWidth : Float } -> ContinuousScale Float
xScale { stintCount, segmentWidth } =
    let
        domainUpper =
            if stintCount <= 1 then
                1

            else
                stintCount - 1

        rangeStart =
            axisOffset + padding + (segmentGap / 2)

        rangeEnd =
            (chartWidth - padding - (segmentGap / 2) - segmentWidth)
                |> Basics.max rangeStart
    in
    Scale.linear ( rangeStart, rangeEnd ) ( 0, toFloat domainUpper )


{-| Small histogram for a list of `Lap`s.

Takes an `Analysis` context, a coefficient to clamp the x-axis upper bound
relative to the fastest lap time, and the laps to render.

-}
view : Analysis -> Float -> List Lap -> Html msg
view { fastestLapTime, slowestLapTime } coefficient laps =
    let
        stints =
            splitIntoStints laps

        stintCount =
            List.length stints

        segmentWidth =
            segmentWidthFor stintCount

        xScale_ =
            xScale { stintCount = stintCount, segmentWidth = segmentWidth }

        yScale_ =
            yScale
                ( toFloat fastestLapTime
                , min (toFloat fastestLapTime * coefficient) (toFloat slowestLapTime)
                )

        positionedStints =
            stints
                |> List.indexedMap
                    (\index stint ->
                        { offset = Scale.convert xScale_ (toFloat index)
                        , stint = stint
                        }
                    )

        color lap =
            if isCurrentLap lap then
                performanceLevel { time = lap.time, personalBest = lap.best, fastest = fastestLapTime }
                    |> Performance.toColorVariable

            else
                "oklch(1 0 0 / 0.2)"

        isCurrentLap { lap } =
            List.length laps == lap
    in
    svg
        [ TypedSvgAttributes.viewBox 0 0 chartWidth chartHeight
        , SvgAttributes.css [ width (Css.px chartWidth), height (Css.px chartHeight) ]
        ]
        [ yAxis yScale_
        , boxPlotColumns
            { stints = positionedStints
            , segmentWidth = segmentWidth
            , yScale = yScale_
            , colorForCurrent = color
            , isCurrentLap = isCurrentLap
            }
        ]


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
        [ TypedSvgAttributes.transform [ Translate axisOffset 0 ]
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


boxPlotColumns :
    { stints : List { offset : Float, stint : HistogramStint }
    , segmentWidth : Float
    , yScale : ContinuousScale Float
    , colorForCurrent : Lap -> String
    , isCurrentLap : Lap -> Bool
    }
    -> Svg msg
boxPlotColumns ({ stints, segmentWidth, colorForCurrent, isCurrentLap } as props) =
    if segmentWidth <= 0 then
        g [] []

    else
        stints
            |> List.filterMap
                (\{ offset, stint } ->
                    computeStatistics stint.laps
                        |> Just
                        |> Maybe.map
                            (\stats ->
                                { offset = offset
                                , width = segmentWidth
                                , stats = stats
                                , fill = "oklch(0.82 0.02 260 / 0.38)"
                                , currentLap =
                                    stint.laps
                                        |> List.filter isCurrentLap
                                        |> List.head
                                }
                            )
                )
            |> List.map (column props.yScale colorForCurrent)
            |> g []


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


gapsWidthFor : Int -> Float
gapsWidthFor stintCount =
    toFloat (Basics.max 0 (stintCount - 1)) * segmentGap


splitIntoStints : List Lap -> List HistogramStint
splitIntoStints laps =
    let
        finalize : Driver -> List Lap -> Dict String Int -> List HistogramStint -> ( List HistogramStint, Dict String Int )
        finalize driver collectedLaps driverCounts stintsAccum =
            let
                key =
                    driver.name

                previous =
                    Dict.get key driverCounts |> Maybe.withDefault 0

                stintNumber =
                    previous + 1

                countsNext =
                    Dict.insert key stintNumber driverCounts

                stint =
                    { driver = driver
                    , stintNumber = stintNumber
                    , laps = List.reverse collectedLaps
                    }
            in
            ( stint :: stintsAccum, countsNext )

        step lap ( currentStint, driverCounts, stintsSoFar ) =
            case currentStint of
                Nothing ->
                    ( Just ( lap.driver, [ lap ] ), driverCounts, stintsSoFar )

                Just ( currentDriver, currentLaps ) ->
                    if currentDriver == lap.driver then
                        ( Just ( currentDriver, lap :: currentLaps ), driverCounts, stintsSoFar )

                    else
                        let
                            ( stintsAccumAfter, countsAfter ) =
                                finalize currentDriver currentLaps driverCounts stintsSoFar
                        in
                        ( Just ( lap.driver, [ lap ] ), countsAfter, stintsAccumAfter )

        finish ( currentStint, driverCounts, stintsSoFar ) =
            case currentStint of
                Nothing ->
                    ( stintsSoFar, driverCounts )

                Just ( driver, currentLaps ) ->
                    finalize driver currentLaps driverCounts stintsSoFar

        ( foldedCurrent, foldedCounts, foldedStints ) =
            List.foldl step ( Nothing, Dict.empty, [] ) laps

        ( finalized, _ ) =
            finish ( foldedCurrent, foldedCounts, foldedStints )
    in
    finalized |> List.reverse


column : ContinuousScale Float -> (Lap -> String) -> { offset : Float, width : Float, stats : BoxStats, fill : String, currentLap : Maybe Lap } -> Svg msg
column yScale_ colorForCurrent { offset, width, stats, fill, currentLap } =
    let
        boxWidth =
            Basics.max 1 width

        left =
            offset

        center =
            left + (boxWidth / 2)

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

        currentLapMarker =
            currentLap
                |> Maybe.map (\lap -> currentLapCircle (colorForCurrent lap) yScale_ center lap)
                |> Maybe.map List.singleton
                |> Maybe.withDefault []
    in
    g []
        ([ whisker
            { color = "#5a5a5a"
            , center = center
            , width = boxWidth * 0.3
            , upperWhiskerY = Scale.convert yScale_ stats.max
            , boxTop = boxTop
            , boxBottom = boxBottom
            , lowerWhiskerY = Scale.convert yScale_ stats.min
            }
         , box
            { top = boxTop
            , left = left
            , width = boxWidth
            , height = Basics.max 1 (boxBottom - boxTop)
            , fill = fill
            , strokeColor = "#2e2e2e"
            }
         , medianLine
            { left = left
            , width = boxWidth
            , medianY = Scale.convert yScale_ stats.median
            , color = "#f59f42"
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
    , fill : String
    , strokeColor : String
    }
    -> Svg msg
box { top, left, width, height, fill, strokeColor } =
    rect
        [ InPx.x left
        , InPx.y top
        , InPx.width width
        , InPx.height height
        , SvgAttributes.fill fill
        , SvgAttributes.stroke strokeColor
        , SvgAttributes.strokeWidth "1"
        ]
        []


whisker :
    { color : String
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
        , SvgAttributes.stroke color
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
    , color : String
    }
    -> Svg msg
medianLine { left, width, medianY, color } =
    line
        [ TypedSvgAttributes.x1 (px left)
        , TypedSvgAttributes.y1 (px medianY)
        , TypedSvgAttributes.x2 (px (left + width))
        , TypedSvgAttributes.y2 (px medianY)
        , SvgAttributes.strokeWidth "1"
        , SvgAttributes.stroke color
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
        , SvgAttributes.stroke "#1c1c1c"
        , SvgAttributes.strokeWidth "0.6"
        ]
        []
