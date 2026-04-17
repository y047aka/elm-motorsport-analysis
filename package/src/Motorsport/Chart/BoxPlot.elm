module Motorsport.Chart.BoxPlot exposing (view)

import Axis exposing (tickCount, tickFormat, tickSizeInner, tickSizeOuter)
import Css exposing (Color)
import Css.Extra
import Css.Global exposing (descendants, each)
import Html.Styled exposing (Html)
import List.Extra as ListExtra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
import Scale exposing (ContinuousScale)
import Statistics
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, line, rect, svg, text_)
import Svg.Styled.Attributes as SvgAttributes
import TypedSvg.Styled.Attributes as TypedSvgAttributes
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Transform(..), px)


padding : Float
padding =
    15


paddingLeft : Float
paddingLeft =
    padding + 45


paddingBottom : Float
paddingBottom =
    padding + 20


axisStrokeColor : String
axisStrokeColor =
    "#555"


type alias BoxStats =
    { firstQuartile : Float
    , median : Float
    , thirdQuartile : Float
    , max : Float
    , min : Float
    , outliers : List Float
    }


type alias HourlyBoxPlot =
    { carNumber : String
    , hourIndex : Int
    , stats : BoxStats
    , color : Color
    , currentLapTime : Maybe Duration
    }


type alias PositionedBoxPlot =
    { boxPlot : HourlyBoxPlot
    , x : Float
    , width : Float
    }


hourInMillis : Int
hourInMillis =
    3600000


groupGap : Float
groupGap =
    20


innerGap : Float
innerGap =
    4


maxBoxWidth : Float
maxBoxWidth =
    60


toHourlyGroups : List Lap -> List { hourIndex : Int, laps : List Lap }
toHourlyGroups laps =
    laps
        |> ListExtra.groupWhile (\a b -> a.elapsed // hourInMillis == b.elapsed // hourInMillis)
        |> List.map
            (\( first, rest ) ->
                { hourIndex = first.elapsed // hourInMillis
                , laps = first :: rest
                }
            )


computeLayout : { width : Float, height : Float } -> List (List HourlyBoxPlot) -> List PositionedBoxPlot
computeLayout size grouped =
    let
        numGroups =
            List.length grouped

        carsPerGroup =
            grouped |> List.map List.length |> List.maximum |> Maybe.withDefault 1

        availableWidth =
            size.width - paddingLeft - padding

        totalGroupGaps =
            toFloat (max 0 (numGroups - 1)) * groupGap

        groupWidth =
            (availableWidth - totalGroupGaps) / toFloat (max 1 numGroups)

        rawBoxWidth =
            (groupWidth - toFloat (max 0 (carsPerGroup - 1)) * innerGap) / toFloat (max 1 carsPerGroup)

        boxWidth =
            Basics.min rawBoxWidth maxBoxWidth

        usedGroupWidth =
            boxWidth * toFloat carsPerGroup + innerGap * toFloat (max 0 (carsPerGroup - 1))

        groupOffset =
            (groupWidth - usedGroupWidth) / 2
    in
    grouped
        |> List.indexedMap
            (\gi group ->
                let
                    groupStartX =
                        paddingLeft + toFloat gi * (groupWidth + groupGap) + groupOffset
                in
                group
                    |> List.indexedMap
                        (\ci bp ->
                            { boxPlot = bp
                            , x = groupStartX + toFloat ci * (boxWidth + innerGap)
                            , width = boxWidth
                            }
                        )
            )
        |> List.concat


view : { width : Float, height : Float } -> Analysis -> Standings -> List StandingsEntry -> Html msg
view size analysis standings selectedCars =
    let
        hourlyBoxPlots =
            selectedCars
                |> List.concatMap
                    (\item ->
                        let
                            color =
                                Manufacturer.toColorWithFallback item.metadata

                            carNumber =
                                item.metadata.carNumber

                            groups =
                                toHourlyGroups (Standings.getCarHistory item.metadata.carNumber standings)

                            lastHourIndex =
                                groups |> ListExtra.last |> Maybe.map .hourIndex
                        in
                        groups
                            |> List.map
                                (\group ->
                                    { carNumber = carNumber
                                    , hourIndex = group.hourIndex
                                    , stats = computeStatistics group.laps
                                    , color = color
                                    , currentLapTime =
                                        if Just group.hourIndex == lastHourIndex then
                                            item.currentLapTime

                                        else
                                            Nothing
                                    }
                                )
                    )

        groupedByHour =
            hourlyBoxPlots
                |> List.sortBy .hourIndex
                |> ListExtra.groupWhile (\a b -> a.hourIndex == b.hourIndex)
                |> List.map (\( first, rest ) -> first :: rest)

        positionedBoxPlots =
            computeLayout size groupedByHour

        yScale_ =
            computeGlobalYScale size analysis (List.concat groupedByHour)
    in
    svg
        [ TypedSvgAttributes.viewBox 0 0 size.width size.height
        , SvgAttributes.width "100%"
        ]
        [ yAxis yScale_
        , xAxisLabels size positionedBoxPlots
        , g []
            (positionedBoxPlots |> List.map (renderPositionedBoxPlot yScale_ analysis))
        ]


formatLabel : HourlyBoxPlot -> String
formatLabel { hourIndex, carNumber } =
    "H" ++ String.fromInt (hourIndex + 1) ++ " #" ++ carNumber


xAxisLabels : { width : Float, height : Float } -> List PositionedBoxPlot -> Svg msg
xAxisLabels size positioned =
    let
        tickSize =
            3

        baseline =
            line
                [ TypedSvgAttributes.x1 (px paddingLeft)
                , TypedSvgAttributes.y1 (px 0)
                , TypedSvgAttributes.x2 (px (size.width - padding))
                , TypedSvgAttributes.y2 (px 0)
                , SvgAttributes.stroke axisStrokeColor
                , SvgAttributes.strokeWidth "1"
                ]
                []

        ticksAndLabels =
            positioned
                |> List.map
                    (\p ->
                        let
                            centerX =
                                p.x + p.width / 2
                        in
                        g []
                            [ line
                                [ TypedSvgAttributes.x1 (px centerX)
                                , TypedSvgAttributes.y1 (px 0)
                                , TypedSvgAttributes.x2 (px centerX)
                                , TypedSvgAttributes.y2 (px tickSize)
                                , SvgAttributes.stroke axisStrokeColor
                                , SvgAttributes.strokeWidth "1"
                                ]
                                []
                            , text_
                                [ InPx.x centerX
                                , InPx.y (tickSize + 12)
                                , SvgAttributes.css
                                    [ Css.fill (Css.hsl 0 0 0.7)
                                    , Css.fontSize (Css.px 11)
                                    ]
                                , SvgAttributes.textAnchor "middle"
                                ]
                                [ Svg.Styled.text (formatLabel p.boxPlot) ]
                            ]
                    )
    in
    g
        [ TypedSvgAttributes.transform [ Translate 0 (size.height - paddingBottom) ]
        ]
        (baseline :: ticksAndLabels)


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
                    , Css.fontSize (Css.px 11)
                    ]
                , each
                    [ Css.Global.typeSelector "line"
                    , Css.Global.typeSelector "path"
                    ]
                    [ Css.Extra.strokeWidth 1
                    , Css.property "stroke" axisStrokeColor
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


computeGlobalYScale : { width : Float, height : Float } -> Analysis -> List HourlyBoxPlot -> ContinuousScale Float
computeGlobalYScale size { fastestLapTime } hourlyBoxPlots =
    let
        allValues =
            hourlyBoxPlots
                |> List.concatMap (\h -> [ h.stats.min, h.stats.max ])

        minValue =
            allValues
                |> List.minimum
                |> Maybe.withDefault (toFloat fastestLapTime)
                |> min (toFloat fastestLapTime)

        maxValue =
            allValues
                |> List.maximum
                |> Maybe.withDefault (toFloat fastestLapTime * 1.07)
                |> max (toFloat fastestLapTime * 1.07)
    in
    Scale.linear ( size.height - paddingBottom, padding ) ( minValue, maxValue )


renderPositionedBoxPlot : ContinuousScale Float -> Analysis -> PositionedBoxPlot -> Svg msg
renderPositionedBoxPlot yScale_ analysis { boxPlot, x, width } =
    let
        { stats, color, currentLapTime } =
            boxPlot

        center =
            x + (width / 2)

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

        colorForCurrent time =
            { time = time
            , personalBest = stats.min |> round
            , fastest = analysis.fastestLapTime
            }
                |> Performance.performanceLevel
                |> Performance.toColorVariable

        currentLapMarker =
            currentLapTime
                |> Maybe.map (\time -> currentLapCircle (colorForCurrent time) yScale_ center time)
                |> Maybe.map List.singleton
                |> Maybe.withDefault []
    in
    g []
        ([ whisker
            { color = color
            , center = center
            , width = width * 0.3
            , upperWhiskerY = Scale.convert yScale_ stats.max
            , boxTop = boxTop
            , boxBottom = boxBottom
            , lowerWhiskerY = Scale.convert yScale_ stats.min
            }
         , boxRect
            { top = boxTop
            , left = x
            , width = width
            , height = Basics.max 1 (boxBottom - boxTop)
            , color = color
            }
         , medianLine
            { left = x
            , width = width
            , medianY = Scale.convert yScale_ stats.median
            , color = color
            }
         ]
            ++ outlierDots
            ++ currentLapMarker
        )


boxRect :
    { top : Float
    , left : Float
    , width : Float
    , height : Float
    , color : Color
    }
    -> Svg msg
boxRect { top, left, width, height, color } =
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


currentLapCircle : String -> ContinuousScale Float -> Float -> Duration -> Svg msg
currentLapCircle color yScale_ center time =
    circle
        [ InPx.cx center
        , InPx.cy (Scale.convert yScale_ (toFloat time))
        , InPx.r 2.5
        , SvgAttributes.fill color
        ]
        []
