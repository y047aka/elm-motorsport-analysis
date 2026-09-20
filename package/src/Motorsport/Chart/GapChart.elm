module Motorsport.Chart.GapChart exposing (gapChartView, gapSparkline)

{-| The relative-gap chart: [`RelativeGap`](Motorsport-Analysis-RelativeGap)
drawn full-width with axes ([`gapChartView`](#gapChartView)) or at card size
without them ([`gapSparkline`](#gapSparkline)).

Both are given the cars as [`Rivals`](Motorsport-Analysis-Rivals) and take a
wider ring of it to baseline on than they draw; how much wider, and why, is
[`fightRivals`](#fightRivals).

@docs gapChartView, gapSparkline

-}

import Axis exposing (tickCount, tickFormat, tickPadding, tickSizeInner, tickSizeOuter)
import Html exposing (Html, text)
import List.Extra
import Motorsport.Analysis.RelativeGap as RelativeGap exposing (Baseline)
import Motorsport.Analysis.Rivals as Rivals exposing (Rivals)
import Motorsport.Chart.Common exposing (Dimensions, Emphasis(..), Scales, axisPadding, lapAxis, lapGridLines, renderLine, sortForDrawing, svg, xContinuousScale, yAxis)
import Motorsport.Internal.Statistics exposing (iqrFences)
import Motorsport.Lap exposing (Lap)
import Motorsport.LapRange as LapRange exposing (LapRange)
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot exposing (CarAt)
import Scale
import Svg exposing (Svg, line)
import Svg.Attributes as SvgAttr


type alias CarLine =
    { color : String
    , emphasis : Emphasis
    , carNumber : String
    , laps : List Lap
    }


{-| One drawing unit: a series paired with its points on the vertical axis.
-}
type alias PlottedCar =
    { car : CarLine
    , points : List RelativeGap.Point
    }


lapsOf : LapRange -> LapHistory -> CarAt -> List Lap
lapsOf range lapHistory entry =
    LapHistory.get entry.metadata.carNumber lapHistory
        |> LapRange.within range


carLine : LapRange -> LapHistory -> Emphasis -> CarAt -> CarLine
carLine range lapHistory emphasis entry =
    { color = entry.metadata.manufacturer.color
    , emphasis = emphasis
    , carNumber = entry.metadata.carNumber
    , laps = lapsOf range lapHistory entry
    }


{-| The full chart, with a lap axis and a gap axis.

Ahead of the baseline goes up and behind it goes down, so a line's vertical
motion reads as relative pace.

The rival either side is drawn in full and labelled, the pair beyond them grey
and faint with no end label -- the treatment the position chart gives the rest
of its class.

`Nothing` where the range holds none of the laps the chart would draw; what
stands in its place is the caller's.

-}
gapChartView : LapRange -> LapHistory -> Rivals -> Maybe (Html msg)
gapChartView range lapHistory rivals =
    let
        fighting =
            Rivals.nearest fightRivals rivals
                |> List.map (.metadata >> .carNumber)

        lineOf entry =
            carLine range
                lapHistory
                (if List.member entry.metadata.carNumber fighting then
                    Focused

                 else
                    Muted
                )
                entry

        drawn =
            Rivals.nearest baselineRivals rivals
                |> List.concatMap (lapsOf range lapHistory)
                |> RelativeGap.baseline
                |> Maybe.map
                    (\baseline ->
                        plotGaps
                            { baseline = baseline
                            , display = Rivals.nearest drawnRivals rivals |> List.map lineOf
                            }
                    )
                |> Maybe.withDefault []

        fight =
            drawn |> List.filter (\plotted -> plotted.car.emphasis == Focused)
    in
    -- The cars drawn, not the wider group they are baselined on: a car that
    -- retired before the range began has nothing in it, and neither do the
    -- rivals it is ranked among, while the ring beyond them is still running
    -- and would carry a guard that only asked whether a baseline exists.
    if List.all (.points >> List.isEmpty) drawn then
        Nothing

    else
        Just
            (gapChartViewWith { dimensions = consolidated, showAxes = True }
                ( toFloat range.first, toFloat (max range.last (range.first + 1)) )
                { scaleOn =
                    -- The fight owns the frame, unless the range has left none
                    -- of it to draw and the context is all there is.
                    if List.all (.points >> List.isEmpty) fight then
                        drawn

                    else
                        fight
                , draw = drawn
                }
            )


{-| How far out the full chart reaches, in rivals a side.

`drawnRivals` is one ring past the fight and no further: every extra line is one
more to follow, and what the chart is read for is what two of them are doing to
each other. The ring past the fight is drawn muted for the same reason, and the
vertical band is taken off the fight alone so that it costs the fight no frame.

`baselineRivals` goes two further again, because a baseline averaged from
exactly the cars drawn against it locks them into a mirror image of one another
-- the gaps sum to zero, so the outer lines can only move against each other.

-}
fightRivals : Int
fightRivals =
    1


{-| See [`fightRivals`](#fightRivals).
-}
drawnRivals : Int
drawnRivals =
    2


{-| See [`fightRivals`](#fightRivals).
-}
baselineRivals : Int
baselineRivals =
    4


{-| Each car of `display` against the baseline. How much wider the group behind
that baseline is, and why, is [`fightRivals`](#fightRivals).
-}
plotGaps : { baseline : Baseline, display : List CarLine } -> List PlottedCar
plotGaps { baseline, display } =
    display |> List.map (\car -> { car = car, points = RelativeGap.against baseline car.laps })


{-| The same series at card size and without axes: only the polylines and the
zero baseline, and only `focused` drawn emphasised, the rivals beside it held
back.

The horizontal extent is the laps the focused car actually has inside `range`
rather than the range itself, so a card of a car that has just come out is the
laps it has run and not mostly blank. A card with no rival to compare against,
or with too little of the focused car to draw a line from, is not drawn at all.

-}
gapSparkline : LapRange -> LapHistory -> Rivals -> Html msg
gapSparkline range lapHistory rivals =
    let
        focused =
            Rivals.focused rivals

        -- A card has room for the fight and no more, and baselines a ring
        -- wider for the reason `fightRivals` gives.
        display =
            Rivals.nearest 1 rivals

        lineOf entry =
            carLine range
                lapHistory
                (if entry.metadata.carNumber == focused.metadata.carNumber then
                    Focused

                 else
                    Related
                )
                entry

        group =
            Rivals.nearest 2 rivals
                |> List.concatMap (lapsOf range lapHistory)
                |> RelativeGap.baseline

        -- Blank carNumber to omit the end-of-line label on these narrow cards
        -- (renderLine skips empty strings).
        displayLines =
            display
                |> List.map lineOf
                |> List.map (\line -> { line | carNumber = "" })

        focusedLapNumbers =
            lapsOf range lapHistory focused
                |> List.map (.lap >> toFloat)
    in
    case ( focusedLapNumbers, display, group ) of
        ( _ :: _ :: _, _ :: _ :: _, Just baseline ) ->
            gapChartViewWith { dimensions = rivalStrip, showAxes = False }
                ( List.minimum focusedLapNumbers |> Maybe.withDefault 0
                , List.maximum focusedLapNumbers |> Maybe.withDefault 1
                )
                (let
                    drawn =
                        plotGaps { baseline = baseline, display = displayLines }
                 in
                 { scaleOn = drawn, draw = drawn }
                )

        _ ->
            text ""


{-| What [`gapChartView`](#gapChartView) and [`gapSparkline`](#gapSparkline)
share; they differ only in their dimensions and in `showAxes`.
-}
gapChartViewWith :
    { dimensions : Dimensions, showAxes : Bool }
    -> ( Float, Float )
    -> { scaleOn : List PlottedCar, draw : List PlottedCar }
    -> Html msg
gapChartViewWith { dimensions, showAxes } ( minX, maxX ) { scaleOn, draw } =
    let
        { width, height, padding } =
            dimensions

        scales =
            { xScale = xContinuousScale dimensions ( minX, maxX )
            , yScale = gapYScale dimensions scaleOn
            }

        orderedCars =
            sortForDrawing
                (.car >> .emphasis)
                (.car >> .laps >> List.Extra.last >> Maybe.andThen .position)
                draw
    in
    svg { width = width, height = height }
        (gapDecorations { showAxes = showAxes } dimensions scales ( minX, maxX )
            ++ zeroReferenceLine { x1 = padding.left, x2 = width - padding.right, y = Scale.convert scales.yScale 0 }
            :: List.map (gapLine scales) orderedCars
        )


{-| The vertical scale. Always includes 0, and bounds the range on the IQR band
so that the outliers — pit laps, mostly — are clipped rather than drawn to.

It is taken from `scaleOn` rather than from everything drawn, so that a car kept
in the picture for context cannot cost the cars being compared the frame. A
rival two places away can be a pit stop or a lap adrift, which on a cumulative
scale is far enough to flatten the fight to a line.

-}
gapYScale : Dimensions -> List PlottedCar -> Scale.ContinuousScale Float
gapYScale { height, padding } carsWithGaps =
    let
        allGaps =
            carsWithGaps |> List.concatMap (.points >> List.map .gap)

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
            axisLaps =
                { first = ceiling minX, last = floor maxX }
        in
        [ lapGridLines dimensions scales.xScale axisLaps
        , lapAxis dimensions scales.xScale axisLaps
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
        , points = points |> List.map (\p -> ( p.lap, p.gap ))
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
