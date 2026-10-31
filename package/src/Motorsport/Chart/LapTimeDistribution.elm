module Motorsport.Chart.LapTimeDistribution exposing (view, sparklineOn, sharedBounds, Bounds)

{-| The lap-time distribution chart: each car's racing laps as a kernel density
estimate, which says what a time-series line cannot -- the pace a car holds, and
how tightly it holds it.

The cars are laid over one another on a shared scale, drawn full-width with an
axis ([`view`](#view)) or one car at card size without one
([`sparklineOn`](#sparklineOn)); the card-size curves drawn beside one another
take their scale from [`sharedBounds`](#sharedBounds).

@docs view, sparklineOn, sharedBounds, Bounds

-}

import Axis
import Html exposing (Html, text)
import Internal.Statistics exposing (upperFence)
import Motorsport.Analysis.Pace as Pace
import Motorsport.Analysis.Rivals as Rivals exposing (Rivals)
import Motorsport.Chart.Common as Common exposing (Emphasis(..), consolidated)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.LapRange exposing (LapRange)
import Motorsport.Position exposing (Position)
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Path
import Scale exposing (ContinuousScale)
import Shape
import Statistics
import Svg exposing (Svg, circle, g, text_)
import Svg.Attributes as SvgAttr
import TypedSvg.Attributes exposing (transform)
import TypedSvg.Attributes.InPx as InPx
import TypedSvg.Types exposing (Transform(..))


{-| The car and the rival either side on one scale, the car's own curve the
emphasised one.

Three curves and no more, unlike the gap chart beside it: these overlap where
they are alike, which is exactly where the chart is being read.

`Nothing` where the range holds no lap to describe.

-}
view : LapRange -> Snapshot -> Rivals -> Maybe (Html msg)
view range snapshot rivals =
    let
        lapHistory =
            Snapshot.lapHistory snapshot

        focused =
            Rivals.focused rivals

        series =
            Rivals.fight rivals
                |> List.map
                    (\item ->
                        let
                            own =
                                seriesOf range lapHistory item
                        in
                        if item.metadata.carNumber == focused.metadata.carNumber then
                            own

                        else
                            { own | emphasis = Related }
                    )
    in
    measure series
        |> Maybe.map
            (\{ bounds, kept } ->
                chart
                    { width = consolidated.width
                    , height = consolidated.height
                    , domain = bounds.domain
                    , maxDensity = bounds.maxDensity
                    }
                    kept
            )


{-| One car's own laps at card size, on bounds the cars drawn beside it share
([`sharedBounds`](#sharedBounds)) -- so a time reads at the same place on every
curve of the set, and every curve of it is cut to the same laps. A car with no
laps to describe gets no chart rather than an empty one.
-}
sparklineOn : Bounds -> LapRange -> LapHistory -> CarAt -> Html msg
sparklineOn bounds range lapHistory item =
    chart
        { width = 220, height = 50, domain = bounds.domain, maxDensity = bounds.maxDensity }
        [ withinFence bounds.fence (seriesOf range lapHistory item) ]


{-| The bounds several `Series` share. Aligns the X axis (domain), the lap times
every curve is cut to (fence) and the Y axis (max density) across several cars,
so they are drawn on the same scale in both directions.
-}
type alias Bounds =
    { domain : ( Float, Float )
    , maxDensity : Float
    , fence : Duration
    }


{-| The bounds of a set of curves: the extent of every lap of the set the fence
leaves ([`pooledFence`](#pooledFence)), and the greatest density of the curves
those laps make.
-}
boundsOf : List Series -> Maybe Bounds
boundsOf series =
    measure series
        |> Maybe.map .bounds


{-| The same reading with the laps it kept beside it, so a drawing that goes on
to plot the set need not cut it a second time.
-}
measure : List Series -> Maybe { bounds : Bounds, kept : List Series }
measure series =
    let
        fence =
            pooledFence series

        kept =
            List.map (withinFence fence) series
    in
    domainOf kept
        |> Maybe.map
            (\domain ->
                { bounds =
                    { domain = domain
                    , maxDensity = maxDensityOf domain kept
                    , fence = fence
                    }
                , kept = kept
                }
            )


{-| The lap times a set of curves keeps, drawn together: the upper IQR fence over
every lap the set has to show, rather than one fence per car.

Slow is slow _for the cars a lap is lined up against_, and those cars are already
on one axis. Measured per car the fence reads a wide race -- one driver quick,
one slow -- as a wide fence, and that one car then sets the top of the axis for
its whole class.

The held laps are already gone ([`Lap.atRacePace`](Motorsport-Lap#atRacePace)), so
what this fence rules on is the incident lap, the lap begun behind a procedure and
finished after the restart, and the stint that came to nothing.

A car the fence leaves with nothing to draw gets no curve and a blank row. That
is a loss and not an absence: the car ran, and what it ran is slower than every
lap the class showed at pace, which is the reading the axis is drawn to hold. It
is what a shared axis costs -- a curve of its own would draw that car's slow as
another car's quick.

-}
pooledFence : List Series -> Duration
pooledFence series =
    upperFence (List.concatMap .times series)


{-| The series with the laps its bounds fence out dropped. This decides how wide
a kernel the curve smooths with as well as what it covers: a car's slowest laps
left in smear its curve across an axis that drew itself without them.
-}
withinFence : Duration -> Series -> Series
withinFence fence series =
    { series | times = List.filter (\time -> time <= fence) series.times }


{-| The bounds a set of cars drawn beside one another shares: each car's curve
is built over the range that car has run, and the two axes are drawn over the
lot of them.

The range stays each car's own because a car has run the race it has run; the
fence is the set's, drawn over every lap the set has
([`pooledFence`](#pooledFence)).

`Nothing` where none of the cars has a time at all, which is the one case in
which no car of the set has a curve to draw.

-}
sharedBounds : LapHistory -> List { range : LapRange, car : CarAt } -> Maybe Bounds
sharedBounds lapHistory cars =
    cars
        |> List.map (\{ range, car } -> seriesOf range lapHistory car)
        |> boundsOf


{-| One car's curve: the pace it held inside the range, and the lap it is on
now marked as a point on it.
-}
seriesOf : LapRange -> LapHistory -> CarAt -> Series
seriesOf range lapHistory entry =
    { color = entry.metadata.manufacturer.color
    , emphasis = Focused
    , position = entry.standing.position
    , times = Pace.racingTimes range (LapHistory.get entry.metadata.carNumber lapHistory)
    , lastLap = lastLapTime entry
    }


lastLapTime : CarAt -> Maybe Int
lastLapTime entry =
    case entry.lastLap of
        Snapshot.Completed { rated } ->
            rated |> Maybe.map .time

        Snapshot.NoLapYet ->
            Nothing



-- THE CHART


{-| One car's distribution. `times` is expected to have its outliers already
removed; `lastLap` is marked as a single point on the curve.

`emphasis` and `position` are what the draw order is taken from.

-}
type alias Series =
    { color : String
    , emphasis : Emphasis
    , position : Position
    , times : List Int
    , lastLap : Maybe Int
    }


{-| The shared lap-time domain of a set of `Series`: their whole extent plus a
margin, or `Nothing` when there are no times at all. Given the laps the fence
left, so that the axis ends where the laps that read as pace end.
-}
domainOf : List Series -> Maybe ( Float, Float )
domainOf seriesList =
    let
        allTimes =
            seriesList |> List.concatMap .times |> List.map toFloat
    in
    Statistics.extent allTimes
        |> Maybe.map
            (\( lo, hi ) ->
                let
                    margin =
                        (hi - lo) * 0.1 + 1
                in
                ( lo - margin, hi + margin )
            )


{-| The greatest density across every `Series`, for aligning the density scale
of charts drawn separately. A KDE has area 1, so scaling to this makes curve
height read as pace consistency.
-}
maxDensityOf : ( Float, Float ) -> List Series -> Float
maxDensityOf domain seriesList =
    seriesList
        |> List.filter (\s -> not (List.isEmpty s.times))
        |> List.concatMap (\s -> (densityOf domain s).samples |> List.map Tuple.second)
        |> List.maximum
        |> Maybe.withDefault 1
        |> (\m -> max m 1.0e-9)


{-| Overlay each `Series` on the given domain, at the given density scale.
A `Series` with no times is ignored.
-}
chart : { width : Float, height : Float, domain : ( Float, Float ), maxDensity : Float } -> List Series -> Html msg
chart { width, height, domain, maxDensity } seriesList =
    let
        densities =
            seriesList
                |> List.filter (\s -> not (List.isEmpty s.times))
                |> Common.sortForDrawing .emphasis (.position >> Just)
                |> List.map (densityOf domain)
    in
    if List.isEmpty densities then
        text ""

    else
        let
            xScale =
                Scale.linear ( padding.left, width - padding.right ) domain

            yScale =
                Scale.linear ( height - padding.bottom, padding.top ) ( 0, maxDensity )
        in
        Common.svg { width = width, height = height }
            (xAxis height xScale
                :: List.map (densityShape xScale yScale) densities
            )



-- KDE


{-| How many points the KDE is sampled at.
-}
sampleCount : Int
sampleCount =
    64


{-| Epanechnikov kernel. Zero outside `|u| <= 1`.
-}
epanechnikov : Float -> Float
epanechnikov u =
    if abs u <= 1 then
        0.75 * (1 - u * u)

    else
        0


{-| Bandwidth by Silverman's rule of thumb, floored at 1 ms so that a sample
with no deviation cannot divide by zero.
-}
bandwidth : List Float -> Float
bandwidth xs =
    let
        n =
            List.length xs
    in
    case Statistics.deviation xs of
        Just sd ->
            max 1 (1.06 * sd * toFloat n ^ (-1 / 5))

        Nothing ->
            1


{-| Density at point `x` given bandwidth `h` and sample `xs`.
`d(x) = Σ k((x−t)/h) / (n·h)`.
-}
densityAt : Float -> List Float -> Float -> Float
densityAt h xs x =
    case xs of
        [] ->
            0

        _ ->
            (xs |> List.map (\t -> epanechnikov ((x - t) / h)) |> List.sum)
                / (toFloat (List.length xs) * h)


{-| The x series dividing the domain into `sampleCount` equal parts.
-}
samplePoints : ( Float, Float ) -> List Float
samplePoints ( lo, hi ) =
    List.range 0 (sampleCount - 1)
        |> List.map (\i -> lo + (hi - lo) * toFloat i / toFloat (sampleCount - 1))


type alias Density =
    { series : Series
    , samples : List ( Float, Float )
    , lastLapPoint : Maybe ( Float, Float )
    }


densityOf : ( Float, Float ) -> Series -> Density
densityOf domain series =
    let
        xs =
            List.map toFloat series.times

        h =
            bandwidth xs
    in
    { series = series
    , samples = samplePoints domain |> List.map (\x -> ( x, densityAt h xs x ))
    , lastLapPoint =
        series.lastLap
            |> Maybe.map (\ms -> ( toFloat ms, densityAt h xs (toFloat ms) ))
    }



-- RENDER


{-| How faint the area under a curve is drawn.
-}
fillAlphaOf : Emphasis -> String
fillAlphaOf =
    Common.chooseByEmphasis
        { focused = "0.15"
        , related = "0.07"
        , muted = "0.05"
        }


densityShape : ContinuousScale Float -> ContinuousScale Float -> Density -> Svg msg
densityShape xScale yScale { series, samples, lastLapPoint } =
    let
        strokeStyle =
            Common.strokeStyleOf series.emphasis

        scaled =
            samples
                |> List.map (\( x, d ) -> ( Scale.convert xScale x, Scale.convert yScale d ))

        baseline =
            Scale.convert yScale 0

        areaPoints =
            scaled |> List.map (\( px, py ) -> Just ( ( px, baseline ), ( px, py ) ))

        linePoints =
            scaled |> List.map Just
    in
    g []
        [ Path.element (Shape.area Shape.monotoneInXCurve areaPoints)
            [ SvgAttr.fill ("oklch(from " ++ series.color ++ " l c h / " ++ fillAlphaOf series.emphasis ++ ")") ]
        , Path.element (Shape.line Shape.monotoneInXCurve linePoints)
            [ SvgAttr.stroke series.color
            , SvgAttr.strokeWidth strokeStyle.width
            , SvgAttr.strokeOpacity strokeStyle.opacity
            , SvgAttr.fill "none"
            ]
        , lastLapMarker xScale yScale series lastLapPoint
        ]


{-| Where the latest lap falls on the curve: a dot and its lap time, at the
opacity its curve is stroked at.

A lap beyond the shared axis gets its time at the end it lies past, on the
baseline, rather than nothing at all. The axis is drawn over the laps that read
as pace, and the lap a car is on now need not be one of them -- a field that has
just been held shows every car a lap no curve describes.

-}
lastLapMarker : ContinuousScale Float -> ContinuousScale Float -> Series -> Maybe ( Float, Float ) -> Svg msg
lastLapMarker xScale yScale series lastLapPoint =
    case lastLapPoint of
        Just ( x, d ) ->
            let
                ( lo, hi ) =
                    Scale.domain xScale

                clamped =
                    clamp lo hi x

                beyond =
                    clamped /= x

                px =
                    Scale.convert xScale clamped

                py =
                    if beyond then
                        Scale.convert yScale 0

                    else
                        Scale.convert yScale d

                ( labelX, anchor ) =
                    if x > hi then
                        ( px - 5, "end" )

                    else if x < lo then
                        ( px + 5, "start" )

                    else
                        ( px, "middle" )
            in
            g [ SvgAttr.opacity (Common.strokeStyleOf series.emphasis).opacity ]
                [ circle
                    [ InPx.cx px
                    , InPx.cy py
                    , InPx.r 2.5
                    , SvgAttr.fill series.color
                    ]
                    []
                , text_
                    [ InPx.x labelX
                    , InPx.y (py - 6)
                    , SvgAttr.textAnchor anchor
                    , SvgAttr.fill series.color
                    , SvgAttr.class "text-[9px]"
                    ]
                    [ text (Duration.toString (round x)) ]
                ]

        Nothing ->
            text ""


xAxis : Float -> ContinuousScale Float -> Svg msg
xAxis height xScale =
    g [ transform [ Translate 0 (height - padding.bottom) ], Common.axisStyle ]
        [ Axis.bottom
            [ Axis.tickCount 4
            , Axis.tickFormat (round >> Duration.toString)
            , Axis.tickSizeOuter 0
            ]
            xScale
        ]



-- DIMENSIONS


{-| Room for the X-axis labels, leaving the curve nearly full-bleed sideways.
-}
padding : { top : Float, right : Float, bottom : Float, left : Float }
padding =
    { top = 16, right = 4, bottom = 18, left = 4 }
