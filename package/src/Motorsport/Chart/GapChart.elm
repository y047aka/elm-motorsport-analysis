module Motorsport.Chart.GapChart exposing
    ( CarLine, LinePoint, PlottedCar
    , carLine, groupReferenceByLap, gapPoints, plotGaps
    , consolidated, rivalStrip
    , gapChartView, gapSparkline
    )

{-| Shared primitives for the relative-gap chart. Provides lap-series slicing
(`carLine`), the per-lap group baseline (`groupReferenceByLap`), and the
relative-gap point series (`gapPoints`). Gap charts go through the shared
renderer `gapChartView`, which bundles the vertical-axis computation, zero
baseline, and polyline drawing. Each chart's dimensions are collected as
`Dimensions` presets (`consolidated` / `rivalStrip`). The lap window
([`LapWindow`](Motorsport-Chart-Common)), emphasis
([`Emphasis`](Motorsport-Chart-Common)), and outlier handling
([`iqrFences`](Motorsport-Chart-Common) etc.) come from the shared
`Motorsport.Chart.Common`.

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
import Motorsport.Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
import Scale
import Svg.Styled exposing (Svg, line)
import Svg.Styled.Attributes as SvgAttr


{-| One series' data: color, emphasis, car number, and lap list.
-}
type alias CarLine =
    { color : Css.Color
    , emphasis : Emphasis
    , carNumber : String
    , laps : List Lap
    }


{-| A single point. `value` is the integer vertical quantity (lap time, relative
gap, etc.).
-}
type alias LinePoint =
    { lap : Int
    , value : Int
    }


{-| One drawing unit: a series (`car`) paired with its points projected onto the
vertical axis (`points`). `gapChartView` / `gapSparkline` overlay these on a
single chart.
-}
type alias PlottedCar =
    { car : CarLine
    , points : List LinePoint
    }


{-| Builds one series (color, emphasis, lap list). The lap window is given by
`LapWindow` and the emphasis by `Emphasis`.
-}
carLine : Standings -> LapWindow -> Emphasis -> StandingsEntry -> CarLine
carLine standings window emphasis entry =
    let
        history =
            Standings.getCarHistory entry.metadata.carNumber standings
    in
    { color = Manufacturer.toColorWithFallback entry.metadata
    , emphasis = emphasis
    , carNumber = entry.metadata.carNumber
    , laps =
        case window of
            Recent currentLap ->
                Standings.getRecentLaps { count = 20, currentLap = currentLap } history

            Range ( minLap, maxLap ) ->
                history |> List.filter (\lap -> minLap <= lap.lap && lap.lap <= maxLap)
    }


{-| Full chart overlaying multiple cars' relative-gap progression with an X axis
(lap number) and Y axis (difference from baseline, seconds). The group average of
the given cars (mean cumulative time over non-pit laps) is the baseline = 0 line
(dotted), and each car's `cumulative time − group average` is the vertical
quantity. Faster than baseline (smaller cumulative = ahead) goes up, slower
(larger = behind) goes down, so a line's vertical motion reads directly as
relative pace.

Unlike absolute lap time, subtracting the group average magnifies pace
differences between nearby cars for readability. The vertical axis spans a band
with outliers (two-sided IQR, e.g. pit laps) removed, clipping outliers outside
the frame.

-}
gapChartView : ( Int, Int ) -> Standings -> List StandingsEntry -> Html msg
gapChartView ( minLap, maxLap ) standings entries =
    let
        carLines =
            entries |> List.map (carLine standings (Range ( minLap, maxLap )) Focused)
    in
    if Dict.isEmpty (groupReferenceByLap carLines) then
        text ""

    else
        gapChartViewWith { dimensions = consolidated, showAxes = True }
            ( toFloat minLap, toFloat (max maxLap (minLap + 1)) )
            (plotGaps { reference = carLines, display = carLines })


{-| Builds the relative-gap point series (`cumulative time − baseline`) from the
per-lap group baseline `referenceByLap` and each car's lap list. Laps without a
baseline produce no point and are dropped.
-}
gapPoints : Dict Int Int -> List Lap -> List LinePoint
gapPoints referenceByLap laps =
    laps
        |> List.filterMap
            (\lap ->
                Dict.get lap.lap referenceByLap
                    |> Maybe.map (\ref -> { lap = lap.lap, value = lap.elapsed - ref })
            )


{-| Computes the per-lap group baseline once from the reference population
(`reference`), then projects each displayed car (`display`) onto its relative-gap
point series to build the `PlottedCar` list. The two sets are taken separately so
the reference and displayed populations can differ (the rival comparison uses up
to 5 cars as the baseline and shows 3). Passing the same set yields a chart
referenced to the cars' own group average.
-}
plotGaps : { reference : List CarLine, display : List CarLine } -> List PlottedCar
plotGaps { reference, display } =
    let
        referenceByLap =
            groupReferenceByLap reference
    in
    display |> List.map (\car -> { car = car, points = gapPoints referenceByLap car.laps })


{-| Minimal axis-less sparkline drawing the relative-gap point series: only the
polyline and zero baseline. Takes pre-built `PlottedCar`s (the caller supplies
dimensions and X range). For the full chart with axes, use
[`gapChartView`](#gapChartView).
-}
gapSparkline : Dimensions -> ( Float, Float ) -> List PlottedCar -> Html msg
gapSparkline dimensions range carsWithGaps =
    gapChartViewWith { dimensions = dimensions, showAxes = False } range carsWithGaps


{-| Shared renderer overlaying multiple cars' relative-gap point series. The
vertical axis always includes 0 (group-average pace) and spans a band with
outliers (two-sided IQR, e.g. pit laps) removed, clipping outliers outside the
frame. Faster (smaller cumulative = ahead) goes up, slower (larger = behind) down,
with the 0 line shown dashed. The caller supplies dimensions and X range via a
`Dimensions` preset and `( minX, maxX )` (the consolidated chart and the card
differ only in dimensions). The axes are toggled by the public functions
(`gapChartView` / `gapSparkline`) via `showAxes`.
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

        -- Stack back-to-front: Muted (back) → Related → Focused (front).
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


{-| Builds the vertical scale from the points. Always includes 0 (group-average
pace) and bounds the range by a band with outliers (two-sided IQR, e.g. pit laps)
removed. Maps to screen coordinates as `( padding.top, height - padding.bottom )`
so faster (smaller cumulative = ahead) is up and slower (larger = behind) is down.
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


{-| Builds the axis decorations (back to front: grid lines → X axis → Y axis).
When `showAxes` is False (sparkline) returns empty, leaving only the polylines.
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


{-| Y axis (difference from the baseline = group average). Four ticks, formatting
millisecond values as signed seconds. Draws via the shared `yAxis` wrapper.
-}
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


{-| Formats a Y-axis label: milliseconds to signed seconds at 0.1 s precision
(0 is unsigned).
-}
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


{-| Converts a `PlottedCar` into the shared renderer `renderLine`'s input and
draws one line. The vertical quantity is the relative gap
(`cumulative time − group average`).
-}
gapLine : Scales -> PlottedCar -> Svg msg
gapLine scales { car, points } =
    renderLine scales
        { color = car.color
        , emphasis = car.emphasis
        , label = car.carNumber
        , points = points |> List.map (\p -> ( p.lap, p.value ))
        }


{-| Horizontal dashed line marking group average = 0.
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


{-| Collects only the non-pit laps (no `pitTime`) of the cars and returns, per lap
number, the mean cumulative time. Excluding pit laps keeps the baseline from
jumping. Only cars with a non-pit lap on that lap contribute to the average.
-}
groupReferenceByLap : List CarLine -> Dict Int Int
groupReferenceByLap carLines =
    carLines
        |> List.concatMap .laps
        |> List.filter (\lap -> lap.pitTime == Nothing)
        |> List.foldl
            (\lap ->
                Dict.update lap.lap
                    (\existing ->
                        case existing of
                            Just ( sum, count ) ->
                                Just ( sum + lap.elapsed, count + 1 )

                            Nothing ->
                                Just ( lap.elapsed, 1 )
                    )
            )
            Dict.empty
        |> Dict.map (\_ ( sum, count ) -> sum // count)


{-| Dimensions for the full-width consolidated gap chart. A wide aspect keeps the
rendered height (width × height/width) low when stretched to 100% width. Uses the
shared `axisPadding` to reserve room for the X/Y axis labels.
-}
consolidated : Dimensions
consolidated =
    { width = 1000, height = 250, padding = axisPadding }


{-| Dimensions for the in-card ahead/behind rival comparison (gap). Narrow and
short.
-}
rivalStrip : Dimensions
rivalStrip =
    { width = 200, height = 36, padding = { top = 4, right = 3, bottom = 4, left = 3 } }
