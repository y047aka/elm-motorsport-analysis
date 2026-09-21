module Motorsport.Chart.Common exposing
    ( Emphasis(..), chooseByEmphasis, emphasisRank, sortForDrawing
    , Dimensions, Scales, axisPadding, consolidated, xContinuousScale
    , svg, renderLine, strokeStyleOf
    , axisStyle, lapGridLines, lapAxis, yAxis
    )

{-| Shared foundation for the relative-gap, lap-time distribution and position
charts: the types they draw against, the polyline renderer, the axis and grid
drawing.

@docs Emphasis, chooseByEmphasis, emphasisRank, sortForDrawing
@docs Dimensions, Scales, axisPadding, consolidated, xContinuousScale
@docs svg, renderLine, strokeStyleOf
@docs axisStyle, lapGridLines, lapAxis, yAxis

-}

import Axis exposing (tickFormat, tickPadding, tickSizeInner, tickSizeOuter, ticks)
import List.Extra
import Motorsport.LapRange exposing (LapRange)
import Path
import Scale
import Shape
import Svg exposing (Svg, circle, g, line, text, text_)
import Svg.Attributes as SvgAttr
import TypedSvg.Attributes exposing (transform, viewBox)
import TypedSvg.Attributes.InPx as InPx
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


{-| The size the car detail panel's charts draw at. A wide aspect keeps the
rendered height low once the svg is stretched to 100% width.

One value rather than one per chart: the panel's tabs switch between them in
place, so a chart of another height reads as the panel jumping rather than as
the chart changing.

-}
consolidated : Dimensions
consolidated =
    { width = 1000, height = 250, padding = axisPadding }


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
    Svg.svg
        [ SvgAttr.width "100%"
        , SvgAttr.class "block"
        , viewBox 0 0 width height
        ]
        children


{-| Draws one series as a polyline plus a terminal dot. `points` are
`( lap number, vertical quantity )`, clipped to the X scale's domain. The
terminal dot, and the `label` beside it, are drawn only for the focused series.
-}
renderLine :
    Scales
    -> { color : String, emphasis : Emphasis, label : String, points : List ( Int, Int ) }
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
                    color

        strokeStyle =
            strokeStyleOf emphasis

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


{-| How a series of each emphasis is stroked: the focused one at full weight,
the ones behind it thinner and more transparent.
-}
strokeStyleOf : Emphasis -> { width : String, opacity : String }
strokeStyleOf =
    chooseByEmphasis
        { focused = { width = "2", opacity = "1" }
        , related = { width = "1.5", opacity = "0.5" }
        , muted = { width = "1.5", opacity = "0.3" }
        }


projectPoint : Scales -> ( Int, Int ) -> ( Float, Float )
projectPoint { xScale, yScale } ( x, y ) =
    ( Scale.convert xScale (toFloat x), Scale.convert yScale (toFloat y) )


{-| Polyline colour for `Muted`. Most of the car colour's chroma is dropped
rather than all of it: a fully achromatic line would recede into the background
but stop telling the cars apart.
-}
mutedColorValue : String -> String
mutedColorValue color =
    "oklch(from " ++ color ++ " 0.5 calc(c * 0.2) h)"


terminalMarker : Scales -> { color : String, label : String } -> ( Int, Int ) -> Svg msg
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
            , SvgAttr.fill color
            ]
            []
            :: (if String.isEmpty label then
                    []

                else
                    [ terminalLabel { x = x, y = y, color = color, label = label } ]
               )
        )


terminalLabel : { x : Float, y : Float, color : String, label : String } -> Svg msg
terminalLabel { x, y, color, label } =
    text_
        [ InPx.x (x + terminalDotRadius + 3)
        , InPx.y y
        , SvgAttr.dominantBaseline "central"
        , SvgAttr.fill color
        , SvgAttr.class "text-[9px] font-bold"
        ]
        [ text label ]


terminalDotRadius : Float
terminalDotRadius =
    2.2



-- Axes & grid


{-| Common style for axis text and tick lines. `Axis.bottom`/`Axis.left` draw
their ticks as bare `text`/`line`/`path` elements we don't construct
ourselves, so this reaches them by tag name through Tailwind's descendant
arbitrary variant rather than attributes set on each one individually.
-}
axisStyle : Svg.Attribute msg
axisStyle =
    SvgAttr.class
        "[&_text]:fill-[hsl(0,0%,70%)] [&_text]:text-[9px] [&_line]:stroke-[oklch(0.5_0_0)] [&_line]:[stroke-width:1] [&_path]:stroke-[oklch(0.5_0_0)] [&_path]:[stroke-width:1]"


{-| Vertical grid lines every 5 laps, across the height of the plot area.
-}
lapGridLines : Dimensions -> Scale.ContinuousScale Float -> LapRange -> Svg msg
lapGridLines { height, padding } xScale range =
    let
        gridLaps =
            List.range range.first range.last |> List.filter (\l -> modBy 5 l == 0)

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
                    , SvgAttr.class "stroke-[oklch(0.5_0_0/0.3)] [stroke-width:1]"
                    ]
                    []
            )
            gridLaps


{-| Lap-number X axis (bottom). Places a tick at every lap, with a label every 5
laps.
-}
lapAxis : Dimensions -> Scale.ContinuousScale Float -> LapRange -> Svg msg
lapAxis { height, padding } xScale range =
    let
        allLaps =
            List.range range.first range.last |> List.map toFloat

        axis =
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
        [ axisStyle
        , transform [ Translate 0 (height - padding.bottom) ]
        ]
        [ axis ]


{-| Common wrapper for the Y axis. Ticks and formatting are the caller's; only
the style and the translation are shared.
-}
yAxis : Dimensions -> List (Axis.Attribute Float) -> Scale.ContinuousScale Float -> Svg msg
yAxis { padding } attributes yScale =
    g
        [ axisStyle
        , transform [ Translate padding.left 0 ]
        ]
        [ Axis.left attributes yScale ]
