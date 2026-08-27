module Motorsport.Chart.LapTimeDistribution exposing (Series, domainOf, maxDensityOf, view)

{-| A car's lap-time distribution as a kernel density estimate: pace
consistency, typical lap and spread, which a time-series sparkline does not
show. Passing several `Series` to `view` overlays them on a shared lap-time axis.

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


{-| One car's distribution. `times` is expected to have its outliers already
removed; `lastLap` is marked as a single point on the curve.
-}
type alias Series =
    { color : String
    , emphasis : Emphasis
    , times : List Int
    , lastLap : Maybe Int
    }


{-| The shared lap-time domain aligning several `Series`: their whole extent
plus a margin, or `Nothing` when there are no times at all.
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
            [ SvgAttr.fill ("oklch(from " ++ series.color ++ " l c h / 0.15)") ]
        , Path.element (Shape.line Shape.monotoneInXCurve linePoints)
            [ SvgAttr.stroke series.color
            , SvgAttr.strokeWidth "2"
            , SvgAttr.fill "none"
            ]
        , lastLapMarker xScale yScale series lastLapPoint
        ]


{-| Where the latest lap falls on the curve: a dot and its lap time.
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
                    , SvgAttr.fill series.color
                    ]
                    []
                , text_
                    [ InPx.x px
                    , InPx.y (py - 6)
                    , SvgAttr.textAnchor "middle"
                    , SvgAttr.fill series.color
                    , SvgAttr.css
                        [ Css.fontSize (Css.px 9) ]
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


{-| Room for the X-axis labels, leaving the curve nearly full-bleed sideways.
-}
padding : { top : Float, right : Float, bottom : Float, left : Float }
padding =
    { top = 16, right = 4, bottom = 18, left = 4 }
