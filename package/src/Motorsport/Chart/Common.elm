module Motorsport.Chart.Common exposing
    ( Emphasis(..), chooseByEmphasis, emphasisRank, sortForDrawing
    , LapWindow(..)
    , Dimensions, Scales, axisPadding, xContinuousScale
    , svg, renderLine
    , axisStyle, lapGridLines, lapAxis, yAxis
    , iqrFences, upperFence
    )

{-| Shared foundation for the sparkline, lap-time distribution and position
history charts: the types they draw against, the polyline renderer, the axis and
grid drawing, and the outlier statistics.

@docs Emphasis, chooseByEmphasis, emphasisRank, sortForDrawing
@docs LapWindow
@docs Dimensions, Scales, axisPadding, xContinuousScale
@docs svg, renderLine
@docs axisStyle, lapGridLines, lapAxis, yAxis
@docs iqrFences, upperFence

-}

import Axis exposing (tickFormat, tickPadding, tickSizeInner, tickSizeOuter, ticks)
import Css
import Css.Extra
import Css.Global exposing (descendants, each)
import List.Extra
import Path.Styled as Path
import Scale
import Shape
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, line, text, text_)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Transform(..))



-- Emphasis


{-| Emphasis of a series (polyline). `Focused` is the target car, `Related` the
few cars related to it, and `Muted` every other car.
-}
type Emphasis
    = Focused
    | Related
    | Muted


chooseByEmphasis : { focused : a, related : a, muted : a } -> Emphasis -> a
chooseByEmphasis { focused, related, muted } emphasis =
    case emphasis of
        Focused ->
            focused

        Related ->
            related

        Muted ->
            muted


{-| Draw-order priority, higher being closer to the front, so that the focused
series is not hidden by the cars around it.
-}
emphasisRank : Emphasis -> Int
emphasisRank emphasis =
    case emphasis of
        Muted ->
            0

        Related ->
            1

        Focused ->
            2


{-| Sorts series into draw order, backmost first: by emphasis, then by latest
position so that the cars running higher up are drawn nearer the front. Series
without a position go to the back.
-}
sortForDrawing : (a -> Emphasis) -> (a -> Maybe Int) -> List a -> List a
sortForDrawing toEmphasis toLatestPosition =
    List.sortBy
        (\s -> ( emphasisRank (toEmphasis s), negate (Maybe.withDefault 9999 (toLatestPosition s)) ))



-- Lap window


{-| How to slice the lap column. `Recent` is a window anchored at the target
car's current lap, which keeps stale laps of retired or far-behind neighbours
out of the baseline average; `Range` is a fixed `(minLap, maxLap)`.
-}
type LapWindow
    = Recent Int
    | Range ( Int, Int )



-- Dimensions & scales


{-| A chart's viewBox dimensions and its padding. Each chart defines its own
preset; the ones with a lap axis share [`axisPadding`](#axisPadding).
-}
type alias Dimensions =
    { width : Float
    , height : Float
    , padding :
        { top : Float
        , right : Float
        , bottom : Float
        , left : Float
        }
    }


{-| Padding reserving room for the axis labels, shared by the lap-axis charts.
-}
axisPadding : { top : Float, right : Float, bottom : Float, left : Float }
axisPadding =
    { top = 20, right = 25, bottom = 20, left = 25 }


{-| The scales for drawing polylines. Built once per chart and shared across the
axis, grid and per-series drawing rather than rebuilt per series.
-}
type alias Scales =
    { xScale : Scale.ContinuousScale Float
    , yScale : Scale.ContinuousScale Float
    }


{-| Linear scale mapping the lap number onto the plot width. The Y axis differs
per chart, so each chart builds its own.
-}
xContinuousScale : Dimensions -> ( Float, Float ) -> Scale.ContinuousScale Float
xContinuousScale { width, padding } domain =
    Scale.linear ( padding.left, width - padding.right ) domain



-- Line drawing


{-| Common svg wrapper for charts.
-}
svg : { width : Float, height : Float } -> List (Svg msg) -> Svg msg
svg { width, height } children =
    Svg.Styled.svg
        [ SvgAttr.width "100%"
        , SvgAttr.css [ Css.property "display" "block" ]
        , viewBox 0 0 width height
        ]
        children


{-| Draws one series as a polyline plus a terminal dot. `points` are
`( lap number, vertical quantity )`, clipped to the X scale's domain. The
terminal dot, and the `label` beside it, are drawn only for the focused series.
-}
renderLine :
    Scales
    -> { color : Css.Color, emphasis : Emphasis, label : String, points : List ( Int, Int ) }
    -> Svg msg
renderLine scales { color, emphasis, label, points } =
    let
        ( minX, maxX ) =
            Scale.domain scales.xScale

        visible =
            points |> List.filter (\( x, _ ) -> minX <= toFloat x && toFloat x <= maxX)

        strokeValue =
            case emphasis of
                Muted ->
                    mutedColorValue color

                _ ->
                    color.value

        strokeStyle =
            chooseByEmphasis
                { focused = { width = "2", opacity = "1" }
                , related = { width = "1.5", opacity = "0.5" }
                , muted = { width = "1.5", opacity = "0.3" }
                }
                emphasis

        linePath =
            visible |> List.map (projectPoint scales >> Just) |> Shape.line Shape.linearCurve

        terminalDot =
            case emphasis of
                Focused ->
                    visible
                        |> List.Extra.last
                        |> Maybe.map (terminalMarker scales { color = color, label = label })
                        |> Maybe.withDefault (g [] [])

                _ ->
                    g [] []
    in
    g []
        [ Path.element linePath
            [ SvgAttr.stroke strokeValue
            , SvgAttr.strokeWidth strokeStyle.width
            , SvgAttr.strokeOpacity strokeStyle.opacity
            , SvgAttr.fill "none"
            ]
        , terminalDot
        ]


projectPoint : Scales -> ( Int, Int ) -> ( Float, Float )
projectPoint { xScale, yScale } ( x, y ) =
    ( Scale.convert xScale (toFloat x), Scale.convert yScale (toFloat y) )


{-| Polyline colour for `Muted`. Most of the car colour's chroma is dropped
rather than all of it: a fully achromatic line would recede into the background
but stop telling the cars apart.
-}
mutedColorValue : Css.Color -> String
mutedColorValue color =
    "oklch(from " ++ color.value ++ " 0.5 calc(c * 0.2) h)"


terminalMarker : Scales -> { color : Css.Color, label : String } -> ( Int, Int ) -> Svg msg
terminalMarker scales { color, label } point =
    let
        ( x, y ) =
            projectPoint scales point
    in
    g []
        (circle
            [ InPx.cx x
            , InPx.cy y
            , InPx.r terminalDotRadius
            , SvgAttr.css [ Css.fill color ]
            ]
            []
            :: (if String.isEmpty label then
                    []

                else
                    [ terminalLabel { x = x, y = y, color = color, label = label } ]
               )
        )


terminalLabel : { x : Float, y : Float, color : Css.Color, label : String } -> Svg msg
terminalLabel { x, y, color, label } =
    text_
        [ InPx.x (x + terminalDotRadius + 3)
        , InPx.y y
        , SvgAttr.dominantBaseline "central"
        , SvgAttr.css
            [ Css.fill color
            , Css.fontSize (Css.px 9)
            , Css.fontWeight Css.bold
            ]
        ]
        [ text label ]


terminalDotRadius : Float
terminalDotRadius =
    2.2



-- Axes & grid


{-| Common style for axis text and tick lines.
-}
axisStyle : Css.Style
axisStyle =
    descendants
        [ Css.Global.typeSelector "text"
            [ Css.fill (Css.hsl 0 0 0.7)
            , Css.fontSize (Css.px 9)
            ]
        , each
            [ Css.Global.typeSelector "line"
            , Css.Global.typeSelector "path"
            ]
            [ Css.Extra.strokeWidth 1
            , Css.property "stroke" "oklch(0.5 0 0 / 1)"
            ]
        ]


{-| Vertical grid lines every 5 laps, across the height of the plot area.
-}
lapGridLines : Dimensions -> Scale.ContinuousScale Float -> ( Int, Int ) -> Svg msg
lapGridLines { height, padding } xScale ( minLap, maxLap ) =
    let
        gridLaps =
            List.range minLap maxLap |> List.filter (\l -> modBy 5 l == 0)

        top =
            padding.top

        bottom =
            height - padding.bottom
    in
    g [] <|
        List.map
            (\lap ->
                let
                    x =
                        toFloat lap |> Scale.convert xScale
                in
                line
                    [ SvgAttr.x1 (String.fromFloat x)
                    , SvgAttr.x2 (String.fromFloat x)
                    , SvgAttr.y1 (String.fromFloat top)
                    , SvgAttr.y2 (String.fromFloat bottom)
                    , SvgAttr.css
                        [ Css.property "stroke" "oklch(0.5 0 0 / 0.3)"
                        , Css.Extra.strokeWidth 1
                        ]
                    ]
                    []
            )
            gridLaps


{-| Lap-number X axis (bottom). Places a tick at every lap, with a label every 5
laps.
-}
lapAxis : Dimensions -> Scale.ContinuousScale Float -> ( Int, Int ) -> Svg msg
lapAxis { height, padding } xScale ( minLap, maxLap ) =
    let
        allLaps =
            List.range minLap maxLap |> List.map toFloat

        axis =
            fromUnstyled <|
                Axis.bottom
                    [ ticks allLaps
                    , tickSizeOuter 0
                    , tickSizeInner -3
                    , tickPadding 8
                    , tickFormat
                        (\f ->
                            if modBy 5 (round f) == 0 then
                                String.fromInt (round f)

                            else
                                ""
                        )
                    ]
                    xScale
    in
    g
        [ SvgAttr.css [ axisStyle ]
        , transform [ Translate 0 (height - padding.bottom) ]
        ]
        [ axis ]


{-| Common wrapper for the Y axis. Ticks and formatting are the caller's; only
the style and the translation are shared.
-}
yAxis : Dimensions -> List (Axis.Attribute Float) -> Scale.ContinuousScale Float -> Svg msg
yAxis { padding } attributes yScale =
    g
        [ SvgAttr.css [ axisStyle ]
        , transform [ Translate padding.left 0 ]
        ]
        [ fromUnstyled (Axis.left attributes yScale) ]



-- Outlier handling


{-| IQR outlier fences `[Q1 − 1.5×IQR, Q3 + 1.5×IQR]` for an ascending-sorted
list. `Nothing` when empty.

    iqrFences [ 1, 2, 3, 4, 5, 6, 7, 8 ]
    --> Just { lower = -4, upper = 12 }

-}
iqrFences : List Int -> Maybe { lower : Int, upper : Int }
iqrFences sorted =
    Maybe.map2
        (\q1 q3 ->
            let
                margin =
                    round (1.5 * toFloat (q3 - q1))
            in
            { lower = q1 - margin, upper = q3 + margin }
        )
        (quantile 0.25 sorted)
        (quantile 0.75 sorted)


{-| Upper outlier fence `Q3 + 1.5×IQR`, used as the upper bound of the racing
band. Falls back to the maximum when there are too few values to compute a fence
(0 for an empty list). Input need not be sorted.

    upperFence [ 1, 2, 3, 4, 5, 6, 7, 8 ]
    --> 12

-}
upperFence : List Int -> Int
upperFence values =
    iqrFences (List.sort values)
        |> Maybe.map .upper
        |> Maybe.withDefault (List.maximum values |> Maybe.withDefault 0)


{-| The q-quantile (0–1) of an ascending-sorted list, by nearest rank.
-}
quantile : Float -> List Int -> Maybe Int
quantile q sorted =
    let
        n =
            List.length sorted
    in
    if n == 0 then
        Nothing

    else
        let
            idx =
                clamp 0 (n - 1) (floor (toFloat (n - 1) * q))
        in
        sorted |> List.drop idx |> List.head
