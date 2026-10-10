module Motorsport.Chart.PositionSparkline exposing (sparkline)

{-| One car's places over a stretch of the race, drawn at row size: one stroke,
no axes.

The line is drawn against the car's own best and worst place over the stretch,
not against the class: the places a car fights for are a handful wherever it
stands, and a scale of the whole class would draw nearly every car's line flat
-- flat reads as _moved nowhere_ whether the car fought or sat, and it is the
fighting a row is drawn to show.

[`PositionProgression`](Motorsport-Chart-PositionProgression) draws the same
points with axes, and one car's line among the whole class with nothing
emphasised is that chart's work; this is the same reading shrunk to sit beside
a car's name.

@docs sparkline

-}

import Motorsport.Analysis.ClassPositions exposing (Point)
import Scale
import Svg exposing (Svg)
import Svg.Attributes as SvgAttr


{-| The line in the car's colour, and nothing where the stretch leaves fewer
than two points -- one place held at one lap is not a line, and a chart that
draws lines draws nothing for it.

The `Svg msg` it hands back carries its own pixel width, so the caller sizes
the cell, not the chart.

-}
sparkline : { width : Float, height : Float } -> String -> List Point -> Svg msg
sparkline size color points =
    let
        laps =
            points |> List.map (.lap >> toFloat)

        places =
            points |> List.map (.position >> toFloat)
    in
    case ( extent laps, extent places ) of
        ( Just lapRange, Just placeRange ) ->
            let
                xScale =
                    Scale.linear ( 0.5, size.width - 0.5 ) (spread (Tuple.first lapRange) (Tuple.second lapRange))

                yScale =
                    Scale.linear ( 1.5, size.height - 1.5 ) (spread (Tuple.first placeRange) (Tuple.second placeRange))

                spot point =
                    String.fromFloat (roundTo (Scale.convert xScale (toFloat point.lap)))
                        ++ ","
                        ++ String.fromFloat (roundTo (Scale.convert yScale (toFloat point.position)))
            in
            Svg.svg
                [ SvgAttr.width (px size.width)
                , SvgAttr.height (px size.height)
                , SvgAttr.viewBox ("0 0 " ++ px size.width ++ " " ++ px size.height)
                ]
                [ Svg.polyline
                    [ SvgAttr.points (points |> List.map spot |> String.join " ")
                    , SvgAttr.fill "none"
                    , SvgAttr.stroke color
                    , SvgAttr.strokeWidth "1.25"
                    , SvgAttr.strokeLinejoin "round"
                    , SvgAttr.strokeLinecap "round"
                    ]
                    []
                ]

        _ ->
            Svg.text ""


{-| A stretch spent at one place, or one lap drawn at all, is spread by half
either side: a scale that starts and ends at one value maps every point to
NaN, and the line vanishes rather than drawing the flat fight it is.
-}
extent : List Float -> Maybe ( Float, Float )
extent values =
    Maybe.map2 Tuple.pair (List.minimum values) (List.maximum values)


spread : Float -> Float -> ( Float, Float )
spread low high =
    if low == high then
        ( low - 0.5, high + 0.5 )

    else
        ( low, high )


roundTo : Float -> Float
roundTo =
    (*) 10 >> round >> toFloat >> (*) 0.1


px : Float -> String
px n =
    String.fromFloat n ++ "px"
