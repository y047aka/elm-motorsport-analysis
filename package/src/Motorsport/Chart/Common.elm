module Motorsport.Chart.Common exposing
    ( Emphasis(..), chooseByEmphasis, emphasisRank, sortForDrawing
    , LapWindow(..)
    , Dimensions, Scales, axisPadding, xContinuousScale
    , svg, renderLine
    , axisStyle, lapGridLines, lapAxis, yAxis
    , iqrFences, upperFence
    )

{-| Shared foundation for several charts. Bundles the types — series emphasis
(`Emphasis`), the lap-column window (`LapWindow`), drawing dimensions
(`Dimensions`), and the scales for line drawing (`Scales`) — together with the
common renderer that draws one series as a polyline plus a terminal dot
(`renderLine`), the shared axis/grid drawing (`axisStyle` / `lapGridLines` /
`lapAxis` / `yAxis`), and the outlier statistics helpers (`iqrFences` /
`upperFence`). Referenced by the sparkline, lap-time distribution, and position
history charts.

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


{-| Emphasis of a series (polyline). `Focused` is the target car (thick, opaque,
terminal dot), `Related` is the few cars related to the target (chromatic, thin,
semi-transparent), and `Muted` is every other car (near-achromatic, thin, low
opacity). Avoids branching on booleans (boolean blindness).
-}
type Emphasis
    = Focused
    | Related
    | Muted


{-| Selects a value by emphasis: `.focused` for `Focused`, `.related` for
`Related`, `.muted` for `Muted`. Lets stroke width and opacity branches be
written the same way across charts.
-}
chooseByEmphasis : { focused : a, related : a, muted : a } -> Emphasis -> a
chooseByEmphasis { focused, related, muted } emphasis =
    case emphasis of
        Focused ->
            focused

        Related ->
            related

        Muted ->
            muted


{-| Draw-order priority. Higher is closer to the front (drawn later):
`Muted` (back) < `Related` (middle) < `Focused` (front). Used by `sortForDrawing`
to decide the stacking order so the focused series is not hidden by surrounding
cars.
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


{-| Sorts series into draw order (head of list = backmost). The primary key is
the `Emphasis` rank ascending (`Muted` back → `Focused` front). The secondary key
is the latest position, placing higher ranks (smaller numbers) toward the front.
Series without a position are sent to the back. `toEmphasis` / `toLatestPosition`
extract each key from a series.
-}
sortForDrawing : (a -> Emphasis) -> (a -> Maybe Int) -> List a -> List a
sortForDrawing toEmphasis toLatestPosition =
    List.sortBy
        (\s -> ( emphasisRank (toEmphasis s), negate (Maybe.withDefault 9999 (toLatestPosition s)) ))



-- Lap window


{-| How to slice the lap column. `Recent` is the window of the last 20 laps
anchored at the target car's current lap (keeps stale laps of retired or
far-behind neighbors from contaminating the baseline average). `Range` is a fixed
lap range `(minLap, maxLap)` aligned with the position history.
-}
type LapWindow
    = Recent Int
    | Range ( Int, Int )



-- Dimensions & scales


{-| A chart's viewBox dimensions and its top/right/bottom/left padding
(`padding.top`, etc.). Represents with one type both charts that reserve padding for
axis labels (position history, consolidated gap chart; see `axisPadding`) and charts
with minimal padding (sparkline). Per-kind presets are defined on each chart.
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


{-| Shared padding reserving room for the X/Y axis labels. Symmetric (25 left/right,
20 top/bottom), shared by the lap-axis charts (consolidated gap chart and position
history).
-}
axisPadding : { top : Float, right : Float, bottom : Float, left : Float }
axisPadding =
    { top = 20, right = 25, bottom = 20, left = 25 }


{-| The set of scales for drawing polylines. Built once per chart from
`allPoints` and shared across the axis, grid, and per-series drawing (avoids
rebuilding per series).
-}
type alias Scales =
    { xScale : Scale.ContinuousScale Float
    , yScale : Scale.ContinuousScale Float
    }


{-| Linear scale mapping the lap number (X axis) to screen coordinates. Maps the
given domain `( minX, maxX )` onto the plot width with the horizontal padding
removed. Shared by charts with a lap axis (the Y axis differs per chart, so each
chart builds its own).
-}
xContinuousScale : Dimensions -> ( Float, Float ) -> Scale.ContinuousScale Float
xContinuousScale { width, padding } domain =
    Scale.linear ( padding.left, width - padding.right ) domain



-- Line drawing


{-| Common svg wrapper for charts. Sets `viewBox` to the dimensions at 100% width
and block display, then draws the decorations and each series' polyline together.
The decorations (axis, grid, zero line, etc.) are passed in by each chart.
-}
svg : { width : Float, height : Float } -> List (Svg msg) -> Svg msg
svg { width, height } children =
    Svg.Styled.svg
        [ SvgAttr.width "100%"
        , SvgAttr.css [ Css.property "display" "block" ]
        , viewBox 0 0 width height
        ]
        children


{-| Common renderer that draws one series as a polyline plus a terminal dot.
`points` are integer `( x, y )` values (lap number and vertical quantity),
projected to screen coordinates via `Scales`. Output is clipped to the X-axis
scale domain (`Scale.domain`); points outside it are dropped. Stroke width,
opacity, and color are chosen by `Emphasis` (`Muted` largely drops the car color
and draws near-achromatic); the terminal dot is placed only on the last point of
the focused series (`Focused`). If `label` (e.g. a car number) is non-empty, it
is shown to the right of the terminal dot.
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

        -- Muted (others): drop most of the car color's chroma to recede into the background (not fully achromatic).
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


{-| Projects an integer point `( x, y )` (lap number and vertical quantity) to
screen coordinates via `Scales`.
-}
projectPoint : Scales -> ( Int, Int ) -> ( Float, Float )
projectPoint { xScale, yScale } ( x, y ) =
    ( Scale.convert xScale (toFloat x), Scale.convert yScale (toFloat y) )


{-| Polyline color for `Muted` (other cars unrelated to the target). A fully
achromatic color would lose car identifiability, so this returns a color with the
original car color's chroma (oklch chroma) greatly reduced. Keeping a hint of
color preserves identifiability while receding into the background. Computed with
the `oklch(from …)` relative color syntax.
-}
mutedColorValue : Css.Color -> String
mutedColorValue color =
    "oklch(from " ++ color.value ++ " 0.5 calc(c * 0.2) h)"


{-| Draws the terminal dot (plus a label when needed). Takes the focused series'
last point and projects it via `Scales`. If `label` is non-empty, it is shown to
the right of the dot. Whether to draw at all (Focused only) is decided in
`renderLine`.
-}
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


{-| Label shown to the right of the terminal dot (e.g. a car number). Whether to
draw it is decided by the caller (`renderLine`). Offset right by the radius so it
does not overlap the dot, and vertically centered.
-}
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


{-| Radius of the terminal dot, marking the focused series' latest point.
-}
terminalDotRadius : Float
terminalDotRadius =
    2.2



-- Axes & grid


{-| Common style for axis text and tick lines: small, muted gray, with thin tick
lines. Shared by charts with an axis such as the lap axis or position axis.
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


{-| Vertical grid lines at lap numbers (every 5 laps), drawn across the full
height of the plot area.
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


{-| Common wrapper for the Y axis (left). Tick values and formatting
(`Axis.Attribute`) are chart-specific and passed in by the caller; only the style
and the translation to the left padding are shared.
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


{-| Returns the q-quantile (0–1) of an ascending-sorted list by nearest rank.
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
