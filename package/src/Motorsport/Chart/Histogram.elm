module Motorsport.Chart.Histogram exposing (view)

import Css exposing (px)
import Html.Styled exposing (Html)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (performanceLevel)
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg, g, rect, svg)
import Svg.Styled.Attributes as SvgAttributes
import TypedSvg.Styled.Attributes as TypedSvgAttributes
import TypedSvg.Styled.Attributes.InPx as InPx


w : Float
w =
    200


h : Float
h =
    20


padding : Float
padding =
    1


xScale : ( Int, Float ) -> ContinuousScale Float
xScale ( min, max ) =
    ( toFloat min, max ) |> Scale.linear ( padding, w - padding )


yScale : ( Float, Float ) -> ContinuousScale Float
yScale ( min, max ) =
    ( min, max ) |> Scale.linear ( h - padding, padding )


{-| Small histogram for a list of `Lap`s.

Takes an `Analysis` context, a coefficient to clamp the x-axis upper bound
relative to the fastest lap time, and the laps to render.

-}
view : Analysis -> Float -> List Lap -> Html msg
view { fastestLapTime, slowestLapTime } coefficient laps =
    let
        xScale_ =
            xScale ( fastestLapTime, min (toFloat fastestLapTime * coefficient) (toFloat slowestLapTime) )

        width lap =
            if isCurrentLap lap then
                3

            else
                1

        color lap =
            if isCurrentLap lap then
                performanceLevel { time = lap.time, personalBest = lap.best, fastest = fastestLapTime }
                    |> Performance.toColorVariable

            else
                "oklch(1 0 0 / 0.2)"

        isCurrentLap { lap } =
            List.length laps == lap
    in
    svg [ TypedSvgAttributes.viewBox 0 0 w h, SvgAttributes.css [ Css.width (px 200) ] ]
        [ histogram_
            { x = .time >> toFloat >> Scale.convert xScale_
            , y = always 0 >> Scale.convert (yScale ( 0, 0 ))
            , width = width
            , color = color
            }
            laps
        ]


histogram_ :
    { x : a -> Float, y : a -> Float, width : a -> Float, color : a -> String }
    -> List a
    -> Svg msg
histogram_ { x, y, width, color } laps =
    g [] <|
        List.map
            (\lap ->
                rect
                    [ InPx.x (x lap - 1)
                    , InPx.y (y lap - 10)
                    , InPx.width (width lap)
                    , InPx.height 20
                    , SvgAttributes.fill (color lap)
                    ]
                    []
            )
            laps
