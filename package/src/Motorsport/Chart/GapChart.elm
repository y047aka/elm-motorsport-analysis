module Motorsport.Chart.GapChart exposing
    ( CarLine, LinePoint, PlottedCar
    , carLine, groupReferenceByLap, gapPoints, plotGaps
    , consolidated, rivalStrip
    , gapChartView, gapSparkline
    )

{-| The relative-gap chart: each car's cumulative time against the group
average, drawn full-width with axes ([`gapChartView`](#gapChartView)) or as an
axis-less sparkline ([`gapSparkline`](#gapSparkline)).

@docs CarLine, LinePoint, PlottedCar
@docs carLine, groupReferenceByLap, gapPoints, plotGaps
@docs consolidated, rivalStrip
@docs gapChartView, gapSparkline

-}

import Axis exposing (tickCount, tickFormat, tickPadding, tickSizeInner, tickSizeOuter)
import Css
import Dict exposing (Dict)
import Html.Styled exposing (Html, text)
import List.Extra
import Motorsport.Chart.Common exposing (Dimensions, Emphasis(..), LapWindow(..), Scales, axisPadding, iqrFences, lapAxis, lapGridLines, renderLine, sortForDrawing, svg, xContinuousScale, yAxis)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap exposing (Lap)
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Wec.Manufacturer as Manufacturer
import Scale
import Svg.Styled exposing (Svg, line)
import Svg.Styled.Attributes as SvgAttr


type alias CarLine =
    { color : Css.Color
    , emphasis : Emphasis
    , carNumber : String
    , laps : List Lap
    }


type alias LinePoint =
    { lap : Int
    , value : Int
    }


{-| One drawing unit: a series paired with its points on the vertical axis.
-}
type alias PlottedCar =
    { car : CarLine
    , points : List LinePoint
    }


carLine : LapHistory -> LapWindow -> Emphasis -> CarAt -> CarLine
carLine lapHistory window emphasis entry =
    let
        history =
            LapHistory.get entry.metadata.carNumber lapHistory
    in
    { color = Manufacturer.toColorWithFallback entry.metadata
    , emphasis = emphasis
    , carNumber = entry.metadata.carNumber
    , laps =
        case window of
            Recent currentLap ->
                LapHistory.recentLaps { count = 20, currentLap = currentLap } history

            Range ( minLap, maxLap ) ->
                history |> List.filter (\lap -> minLap <= lap.lap && lap.lap <= maxLap)
    }


{-| The full chart, with a lap axis and a gap axis.

Subtracting the group average — rather than plotting absolute lap time —
magnifies the pace differences between nearby cars. Ahead of the baseline goes
up and behind it goes down, so a line's vertical motion reads as relative pace.

-}
gapChartView : ( Int, Int ) -> LapHistory -> List CarAt -> Html msg
gapChartView ( minLap, maxLap ) lapHistory entries =
    let
        carLines =
            entries |> List.map (carLine lapHistory (Range ( minLap, maxLap )) Focused)
    in
    if Dict.isEmpty (groupReferenceByLap carLines) then
        text ""

    else
        gapChartViewWith { dimensions = consolidated, showAxes = True }
            ( toFloat minLap, toFloat (max maxLap (minLap + 1)) )
            (plotGaps { reference = carLines, display = carLines })


{-| The relative-gap point series, `cumulative time − baseline`. A lap with no
baseline produces no point.
-}
gapPoints : Dict Int Instant -> List Lap -> List LinePoint
gapPoints referenceByLap laps =
    laps
        |> List.filterMap
            (\lap ->
                Dict.get lap.lap referenceByLap
                    |> Maybe.map
                        (\ref ->
                            { lap = lap.lap
                            , value = Instant.since { from = ref, to = lap.elapsed }
                            }
                        )
            )


{-| Compute the baseline once from `reference`, then project each car of
`display` onto it. The two sets are taken separately so that the populations can
differ — the rival comparison baselines on up to 5 cars and shows 3.
-}
plotGaps : { reference : List CarLine, display : List CarLine } -> List PlottedCar
plotGaps { reference, display } =
    let
        referenceByLap =
            groupReferenceByLap reference
    in
    display |> List.map (\car -> { car = car, points = gapPoints referenceByLap car.laps })


{-| The same series without axes: only the polyline and the zero baseline.
-}
gapSparkline : Dimensions -> ( Float, Float ) -> List PlottedCar -> Html msg
gapSparkline dimensions range carsWithGaps =
    gapChartViewWith { dimensions = dimensions, showAxes = False } range carsWithGaps


{-| What [`gapChartView`](#gapChartView) and [`gapSparkline`](#gapSparkline)
share; they differ only in their dimensions and in `showAxes`.
-}
gapChartViewWith :
    { dimensions : Dimensions, showAxes : Bool }
    -> ( Float, Float )
    -> List PlottedCar
    -> Html msg
gapChartViewWith { dimensions, showAxes } ( minX, maxX ) carsWithGaps =
    let
        { width, height, padding } =
            dimensions

        scales =
            { xScale = xContinuousScale dimensions ( minX, maxX )
            , yScale = gapYScale dimensions carsWithGaps
            }

        orderedCars =
            sortForDrawing
                (.car >> .emphasis)
                (.car >> .laps >> List.Extra.last >> Maybe.andThen .position)
                carsWithGaps
    in
    svg { width = width, height = height }
        (gapDecorations { showAxes = showAxes } dimensions scales ( minX, maxX )
            ++ zeroReferenceLine { x1 = padding.left, x2 = width - padding.right, y = Scale.convert scales.yScale 0 }
            :: List.map (gapLine scales) orderedCars
        )


{-| The vertical scale. Always includes 0, and bounds the range on the IQR band
so that the outliers — pit laps, mostly — are clipped rather than drawn to.
-}
gapYScale : Dimensions -> List PlottedCar -> Scale.ContinuousScale Float
gapYScale { height, padding } carsWithGaps =
    let
        allGaps =
            carsWithGaps |> List.concatMap (.points >> List.map .value)

        fences =
            iqrFences (List.sort allGaps)

        inBand gap =
            case fences of
                Just { lower, upper } ->
                    lower <= gap && gap <= upper

                Nothing ->
                    True

        bandGaps =
            allGaps |> List.filter inBand

        minGap =
            List.minimum (0 :: List.map toFloat bandGaps) |> Maybe.withDefault 0

        maxGap =
            List.maximum (0 :: List.map toFloat bandGaps) |> Maybe.withDefault 1 |> (\m -> max m (minGap + 1))

        yPad =
            (maxGap - minGap) * 0.15 + 50
    in
    Scale.linear ( padding.top, height - padding.bottom ) ( minGap - yPad, maxGap + yPad )


{-| The axis decorations, back to front. Empty for the sparkline.
-}
gapDecorations : { showAxes : Bool } -> Dimensions -> Scales -> ( Float, Float ) -> List (Svg msg)
gapDecorations { showAxes } dimensions scales ( minX, maxX ) =
    if showAxes then
        let
            lapRange_ =
                ( ceiling minX, floor maxX )
        in
        [ lapGridLines dimensions scales.xScale lapRange_
        , lapAxis dimensions scales.xScale lapRange_
        , gapAxis dimensions scales.yScale
        ]

    else
        []


gapAxis : Dimensions -> Scale.ContinuousScale Float -> Svg msg
gapAxis dimensions yScale =
    yAxis dimensions
        [ tickCount 4
        , tickSizeOuter 0
        , tickSizeInner -3
        , tickPadding 6
        , tickFormat formatGapTick
        ]
        yScale


formatGapTick : Float -> String
formatGapTick ms =
    let
        seconds =
            toFloat (round (ms / 100)) / 10
    in
    if seconds == 0 then
        "0"

    else if seconds > 0 then
        "+" ++ String.fromFloat seconds

    else
        String.fromFloat seconds


gapLine : Scales -> PlottedCar -> Svg msg
gapLine scales { car, points } =
    renderLine scales
        { color = car.color
        , emphasis = car.emphasis
        , label = car.carNumber
        , points = points |> List.map (\p -> ( p.lap, p.value ))
        }


{-| The dashed line marking the group average.
-}
zeroReferenceLine : { x1 : Float, x2 : Float, y : Float } -> Svg msg
zeroReferenceLine { x1, x2, y } =
    line
        [ SvgAttr.x1 (String.fromFloat x1)
        , SvgAttr.x2 (String.fromFloat x2)
        , SvgAttr.y1 (String.fromFloat y)
        , SvgAttr.y2 (String.fromFloat y)
        , SvgAttr.stroke "oklch(0.5 0 0 / 0.7)"
        , SvgAttr.strokeWidth "1"
        , SvgAttr.strokeDasharray "2 2"
        ]
        []


{-| The mean cumulative time per lap number, over the non-pit laps only —
including the pit laps would make the baseline jump.
-}
groupReferenceByLap : List CarLine -> Dict Int Instant
groupReferenceByLap carLines =
    carLines
        |> List.concatMap .laps
        |> List.filter (\lap -> lap.pitTime == Nothing)
        |> List.foldl
            (\lap ->
                let
                    -- Summing moments is meaningless on its own; the mean of
                    -- them is the moment the group crossed the line.
                    elapsed =
                        Instant.toDuration lap.elapsed
                in
                Dict.update lap.lap
                    (\existing ->
                        case existing of
                            Just ( sum, count ) ->
                                Just ( sum + elapsed, count + 1 )

                            Nothing ->
                                Just ( elapsed, 1 )
                    )
            )
            Dict.empty
        |> Dict.map (\_ ( sum, count ) -> Instant.fromDuration (sum // count))


{-| The full-width chart. A wide aspect keeps the rendered height low once the
svg is stretched to 100% width.
-}
consolidated : Dimensions
consolidated =
    { width = 1000, height = 250, padding = axisPadding }


{-| The in-card rival comparison.
-}
rivalStrip : Dimensions
rivalStrip =
    { width = 200, height = 36, padding = { top = 4, right = 3, bottom = 4, left = 3 } }
