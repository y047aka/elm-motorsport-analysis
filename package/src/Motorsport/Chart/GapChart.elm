module Motorsport.Chart.GapChart exposing (gapChartView, gapSparkline)

{-| The relative-gap chart: each car's cumulative time against the group
average, drawn full-width with axes ([`gapChartView`](#gapChartView)) or at card
size without them ([`gapSparkline`](#gapSparkline)).

Both are given the cars as [`Rivals`](Motorsport-Race-Rivals): the group the
baseline is averaged from is wider than the group drawn against it, for the
reason that type gives.

@docs gapChartView, gapSparkline

-}

import Axis exposing (tickCount, tickFormat, tickPadding, tickSizeInner, tickSizeOuter)
import Dict exposing (Dict)
import Html exposing (Html, text)
import List.Extra
import Motorsport.Chart.Common exposing (Dimensions, Emphasis(..), Scales, axisPadding, iqrFences, lapAxis, lapGridLines, renderLine, sortForDrawing, svg, xContinuousScale, yAxis)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.Rivals as Rivals exposing (Rivals)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Widget as Widget
import Scale
import Svg exposing (Svg, line)
import Svg.Attributes as SvgAttr


type alias CarLine =
    { color : String
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


carLine : LapHistory -> ( Int, Int ) -> Emphasis -> CarAt -> CarLine
carLine lapHistory ( minLap, maxLap ) emphasis entry =
    { color = entry.metadata.manufacturer.color
    , emphasis = emphasis
    , carNumber = entry.metadata.carNumber
    , laps =
        LapHistory.get entry.metadata.carNumber lapHistory
            |> List.filter (\lap -> minLap <= lap.lap && lap.lap <= maxLap)
    }


{-| The full chart, with a lap axis and a gap axis.

Subtracting the group average — rather than plotting absolute lap time —
magnifies the pace differences between nearby cars. Ahead of the baseline goes
up and behind it goes down, so a line's vertical motion reads as relative pace.

The rival either side is drawn in full and labelled, the pair beyond them drawn
muted -- grey and faint, with no end label: the fight is what the chart is for,
and in the manufacturer colours the outer two read as two more cars to follow
rather than as the ground being made up behind. It is the treatment the position
chart gives the rest of the class, for the same reason.

-}
gapChartView : ( Int, Int ) -> LapHistory -> Rivals -> Html msg
gapChartView ( minLap, maxLap ) lapHistory rivals =
    let
        fighting =
            Rivals.nearest fightRivals rivals
                |> List.map (.metadata >> .carNumber)

        lineOf entry =
            carLine lapHistory
                ( minLap, maxLap )
                (if List.member entry.metadata.carNumber fighting then
                    Focused

                 else
                    Muted
                )
                entry

        referenceLines =
            Rivals.nearest baselineRivals rivals
                |> List.map (carLine lapHistory ( minLap, maxLap ) Focused)

        drawn =
            plotGaps
                { reference = referenceLines
                , display = Rivals.nearest drawnRivals rivals |> List.map lineOf
                }

        fight =
            drawn |> List.filter (\plotted -> plotted.car.emphasis == Focused)
    in
    -- The cars drawn, not the wider group they are baselined on: a car that
    -- retired before the range began has nothing in it, and neither do the
    -- rivals it is ranked among, while the ring beyond them is still running
    -- and would carry a guard that only asked whether a baseline exists.
    if List.all (.points >> List.isEmpty) drawn then
        Widget.emptyState "No laps in this range"

    else
        gapChartViewWith { dimensions = consolidated, showAxes = True }
            ( toFloat minLap, toFloat (max maxLap (minLap + 1)) )
            { scaleOn =
                -- The fight owns the frame, unless the range has left none of
                -- it to draw and the context is all there is.
                if List.all (.points >> List.isEmpty) fight then
                    drawn

                else
                    fight
            , draw = drawn
            }


{-| How far out the full chart reaches, in rivals a side.

The vertical scale is an IQR band over the cars drawn, so every extra line
widens it and costs the fight some of the frame; `drawnRivals` is one ring past
the fight and no further. `baselineRivals` goes two further again, because a
baseline averaged from exactly the cars drawn against it locks them into a
mirror image of one another -- the gaps sum to zero, so the outer lines can only
move against each other.

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


{-| The same series at card size and without axes: only the polylines and the
zero baseline, and only `focused` drawn emphasised, the rivals beside it held
back.

The horizontal extent is the laps the focused car actually has inside `window`
rather than the window itself, so a card of a car that has just come out is the
laps it has run and not mostly blank. A card with no rival to compare against,
or with too little of the focused car to draw a line from, is not drawn at all.

-}
gapSparkline : ( Int, Int ) -> LapHistory -> Rivals -> Html msg
gapSparkline window lapHistory rivals =
    let
        focused =
            Rivals.focused rivals

        -- A card has room for the fight and no more, and baselines a ring
        -- wider for the reason `fightRivals` gives.
        display =
            Rivals.nearest 1 rivals

        lineOf entry =
            carLine lapHistory
                window
                (if entry.metadata.carNumber == focused.metadata.carNumber then
                    Focused

                 else
                    Related
                )
                entry

        referenceLines =
            Rivals.nearest 2 rivals |> List.map lineOf

        -- Blank carNumber to omit the end-of-line label on these narrow cards
        -- (renderLine skips empty strings).
        displayLines =
            display
                |> List.map lineOf
                |> List.map (\line -> { line | carNumber = "" })

        focusedLapNumbers =
            carLine lapHistory window Focused focused
                |> .laps
                |> List.map (.lap >> toFloat)
    in
    case ( focusedLapNumbers, display, Dict.isEmpty (groupReferenceByLap referenceLines) ) of
        ( _ :: _ :: _, _ :: _ :: _, False ) ->
            gapChartViewWith { dimensions = rivalStrip, showAxes = False }
                ( List.minimum focusedLapNumbers |> Maybe.withDefault 0
                , List.maximum focusedLapNumbers |> Maybe.withDefault 1
                )
                (let
                    drawn =
                        plotGaps { reference = referenceLines, display = displayLines }
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
        |> List.filter Lap.isRacingLap
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
