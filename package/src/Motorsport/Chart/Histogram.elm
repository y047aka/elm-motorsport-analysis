module Motorsport.Chart.Histogram exposing (view)

import Html exposing (Html)
import Motorsport.BestTimes as BestTimes exposing (Holder)
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (performanceLevel)
import Scale exposing (ContinuousScale)
import Svg exposing (Svg, g, rect, svg)
import Svg.Attributes as SvgAttributes
import TypedSvg.Attributes as TypedSvgAttributes
import TypedSvg.Attributes.InPx as InPx


w : Float
w =
    200


h : Float
h =
    20


padding : Float
padding =
    1


xContinuousScale : ( Int, Float ) -> ContinuousScale Float
xContinuousScale ( min, max ) =
    ( toFloat min, max ) |> Scale.linear ( padding, w - padding )


yContinuousScale : ( Float, Float ) -> ContinuousScale Float
yContinuousScale ( min, max ) =
    ( min, max ) |> Scale.linear ( h - padding, padding )


{-| Small histogram for a list of `Lap`s.

Takes the fastest/slowest reference times, a coefficient to clamp the x-axis
upper bound relative to the fastest lap time, and the laps to render.

-}
view : { a | fastestLapTime : Maybe Holder, slowestLapTime : Maybe Holder } -> Float -> List Lap -> Html msg
view bestTimes coefficient laps =
    let
        fastestLapTime =
            BestTimes.timeOf bestTimes.fastestLapTime

        -- The axis needs actual numbers; a record no lap has set is worth
        -- nothing to it, which collapses the scale to a point and draws nothing.
        fastestMs =
            Maybe.withDefault 0 fastestLapTime

        slowestMs =
            Maybe.withDefault 0 (BestTimes.timeOf bestTimes.slowestLapTime)

        xScale =
            xContinuousScale ( fastestMs, min (toFloat fastestMs * coefficient) (toFloat slowestMs) )

        yScale =
            yContinuousScale ( 0, 0 )

        width lap =
            if isCurrentLap lap then
                3

            else
                1

        color lap =
            if isCurrentLap lap then
                lap.time
                    |> Maybe.map
                        (\time ->
                            performanceLevel
                                { time = time
                                , personalBest = lap.best
                                , fastest = fastestLapTime
                                }
                        )
                    |> Maybe.withDefault Performance.Standard
                    |> Performance.toColorVariable

            else
                "oklch(1 0 0 / 0.2)"

        isCurrentLap { lap } =
            List.length laps == lap

        -- A lap the source data has no time for has nowhere to go on the axis.
        timedLaps =
            List.filter (\lap -> lap.time /= Nothing) laps
    in
    svg [ TypedSvgAttributes.viewBox 0 0 w h, SvgAttributes.style "width: 200px;" ]
        [ histogram_
            { x = .time >> Maybe.withDefault 0 >> toFloat >> Scale.convert xScale
            , y = always 0 >> Scale.convert yScale
            , width = width
            , color = color
            }
            timedLaps
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
