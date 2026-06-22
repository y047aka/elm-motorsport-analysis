module Motorsport.Chart.LapTimeDistribution exposing (Series, domainOf, maxDensityOf, view)

{-| A chart visualizing a car's lap-time distribution as a smooth kernel density
estimate (KDE) curve. It shows "pace consistency, typical lap, and spread" — hard
to read from a time-series sparkline (progression) — as a distribution, making
multi-car comparison easy. Following elm-visualization's Peaks example, the density
is drawn as a translucent fill (area) plus a solid line (line), and a single marker
shows where the latest lap (`lastLap`) falls on the distribution.

One car or many is drawn by the same `view`. Passing multiple Series overlays them
on a shared X axis (lap time).

@docs Series, domainOf, maxDensityOf, view

-}

import Axis
import Css
import Html.Styled exposing (Html, text)
import Motorsport.Chart.Common as Common exposing (Emphasis)
import Motorsport.Duration as Duration
import Path.Styled as Path
import Scale exposing (ContinuousScale)
import Shape
import Statistics
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, text_)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes exposing (transform)
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Transform(..))


{-| Data for one distribution chart. `times` is the outlier-removed racing lap
times (ms); `lastLap` is the latest lap time (ms) shown as a single point on the
distribution.
-}
type alias Series =
    { color : Css.Color
    , emphasis : Emphasis
    , times : List Int
    , lastLap : Maybe Int
    }


{-| The shared domain that aligns multiple Series on the X axis (lap time). Returns
the extent of all `times` with a margin added on both sides. When every `times` is
empty, returns `Nothing`.
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


{-| Returns the maximum density across all Series within the shared domain. Used to
align the Y-axis (density) scale across multiple charts. Since a KDE is a
probability density with area 1, normalizing by this maximum makes the curve height
a direct comparison of "distribution sharpness = pace consistency". Returns a floor
value when there is no data.
-}
maxDensityOf : ( Float, Float ) -> List Series -> Float
maxDensityOf domain seriesList =
    seriesList
        |> List.filter (\s -> not (List.isEmpty s.times))
        |> List.concatMap (\s -> (densityOf domain s).samples |> List.map Tuple.second)
        |> List.maximum
        |> Maybe.withDefault 1
        |> (\m -> max m 1.0e-9)


{-| Overlays each Series' KDE density curve using the given shared domain and shared
`maxDensity`. On top of the fill (area) plus solid line (line), it places a small
marker and a lap-time label at the latest lap. Spanning the Y axis by the
caller-supplied `maxDensity` aligns the height of separately drawn charts. Series
with all-empty `times` are ignored, and if there is nothing to draw it returns empty.
-}
view : { width : Float, height : Float, domain : ( Float, Float ), maxDensity : Float } -> List Series -> Html msg
view { width, height, domain, maxDensity } seriesList =
    let
        densities =
            seriesList
                |> List.filter (\s -> not (List.isEmpty s.times))
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


{-| Number of points to sample the KDE at (the number of equal divisions of the
domain).
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


{-| Bandwidth by Silverman's rule of thumb `1.06 * σ * n^(-1/5)`. A floor (1 ms) is
applied to avoid division by zero.
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


densityShape : ContinuousScale Float -> ContinuousScale Float -> Density -> Svg msg
densityShape xScale yScale { series, samples, lastLapPoint } =
    let
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
            [ SvgAttr.fill ("oklch(from " ++ series.color.value ++ " l c h / 0.15)") ]
        , Path.element (Shape.line Shape.monotoneInXCurve linePoints)
            [ SvgAttr.stroke series.color.value
            , SvgAttr.strokeWidth "2"
            , SvgAttr.fill "none"
            ]
        , lastLapMarker xScale yScale series lastLapPoint
        ]


{-| Shows where the latest lap (`lastLap`) falls on the distribution curve with a
small dot plus a lap-time label. Draws nothing when there is no `lastLap`.
-}
lastLapMarker : ContinuousScale Float -> ContinuousScale Float -> Series -> Maybe ( Float, Float ) -> Svg msg
lastLapMarker xScale yScale series lastLapPoint =
    case lastLapPoint of
        Just ( x, d ) ->
            let
                px =
                    Scale.convert xScale x

                py =
                    Scale.convert yScale d
            in
            g []
                [ circle
                    [ InPx.cx px
                    , InPx.cy py
                    , InPx.r 2.5
                    , SvgAttr.css [ Css.fill series.color ]
                    ]
                    []
                , text_
                    [ InPx.x px
                    , InPx.y (py - 6)
                    , SvgAttr.textAnchor "middle"
                    , SvgAttr.css
                        [ Css.fill series.color
                        , Css.fontSize (Css.px 9)
                        ]
                    ]
                    [ text (Duration.toString (round x)) ]
                ]

        Nothing ->
            text ""


xAxis : Float -> ContinuousScale Float -> Svg msg
xAxis height xScale =
    g [ transform [ Translate 0 (height - padding.bottom) ], SvgAttr.css [ Common.axisStyle ] ]
        [ fromUnstyled <|
            Axis.bottom
                [ Axis.tickCount 4
                , Axis.tickFormat (round >> Duration.toString)
                , Axis.tickSizeOuter 0
                ]
                xScale
        ]



-- DIMENSIONS


{-| Padding reserving room for the X-axis labels (bottom) while keeping the density
curve nearly full-bleed left/right.
-}
padding : { top : Float, right : Float, bottom : Float, left : Float }
padding =
    { top = 16, right = 4, bottom = 18, left = 4 }
