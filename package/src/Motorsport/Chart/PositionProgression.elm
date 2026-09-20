module Motorsport.Chart.PositionProgression exposing (view)

{-| [`ClassPositions`](Motorsport-Analysis-ClassPositions) drawn as one line per
car, the cars being compared picked out of the class behind them.

@docs view

-}

import Axis exposing (tickFormat, tickSizeInner, tickSizeOuter, ticks)
import Html exposing (Html)
import Internal.Color exposing (Color)
import List.Extra
import Motorsport.Analysis.ClassPositions as ClassPositions
import Motorsport.Analysis.Rivals as Rivals exposing (Rivals)
import Motorsport.Chart.Common exposing (Dimensions, Emphasis(..), Scales, consolidated, lapAxis, lapGridLines, renderLine, sortForDrawing, svg, xContinuousScale, yAxis)
import Motorsport.LapRange exposing (LapRange)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race.Snapshot exposing (Snapshot)
import Scale exposing (ContinuousScale)
import Svg exposing (Svg)


{-| `Nothing` where the range leaves no car of the class with a line to draw.
-}
view : LapRange -> Snapshot -> Rivals -> Maybe (Html msg)
view range snapshot rivals =
    case classProgressionSeries range snapshot rivals of
        [] ->
            Nothing

        series ->
            Just (positionProgressionChart consolidated series)


{-| One line per car of the class, the cars of `rivals` emphasised.

A car with a single point is left out: one place held at one lap is not a line,
and the chart draws lines.

-}
classProgressionSeries : LapRange -> Snapshot -> Rivals -> List PositionSeries
classProgressionSeries range snapshot rivals =
    let
        highlighted =
            Rivals.fight rivals |> List.map (.metadata >> .carNumber)
    in
    ClassPositions.byCar range (Rivals.class rivals) snapshot
        |> List.filter (\( _, points ) -> List.length points >= 2)
        |> List.map
            (\( item, points ) ->
                { points = points
                , color = Manufacturer.color item.metadata.manufacturer
                , carNumber = item.metadata.carNumber
                , emphasis =
                    if List.member item.metadata.carNumber highlighted then
                        Focused

                    else
                        Muted
                }
            )


type alias PositionSeries =
    { points : List ClassPositions.Point
    , color : Color
    , carNumber : String
    , emphasis : Emphasis
    }


{-| The lap numbers the point series spans, which is what the chart drew rather
than what it was asked to read. Lap 1 to lap 1 when there is nothing.
-}
lapExtent : List ClassPositions.Point -> LapRange
lapExtent positions =
    let
        laps =
            positions |> List.map .lap
    in
    { first = List.minimum laps |> Maybe.withDefault 1
    , last = List.maximum laps |> Maybe.withDefault 1
    }


positionProgressionChart : Dimensions -> List PositionSeries -> Html msg
positionProgressionChart dimensions series =
    let
        allPoints =
            series |> List.concatMap .points

        axisLaps =
            lapExtent allPoints

        scales =
            { xScale = xContinuousScale dimensions ( toFloat axisLaps.first, toFloat axisLaps.last )
            , yScale = yContinuousScale dimensions allPoints
            }

        -- Stack back-to-front: Muted (back) → Related → Focused (front).
        orderedSeries =
            sortForDrawing .emphasis (.points >> List.Extra.last >> Maybe.map .position) series
    in
    svg { width = dimensions.width, height = dimensions.height }
        ([ lapGridLines dimensions scales.xScale axisLaps
         , lapAxis dimensions scales.xScale axisLaps
         , positionAxis dimensions scales.yScale
         ]
            ++ List.map (positionLine scales) orderedSeries
        )


yContinuousScale : Dimensions -> List ClassPositions.Point -> ContinuousScale Float
yContinuousScale { height, padding } positions =
    let
        allPositions =
            positions |> List.map .position

        ( minPos, maxPos ) =
            ( List.minimum allPositions |> Maybe.withDefault 1
            , List.maximum allPositions |> Maybe.withDefault 1
            )

        paddingY =
            max 1 ((maxPos - minPos) // 10)

        adjustedMin =
            max 0 (minPos - paddingY)

        adjustedMax =
            maxPos + paddingY
    in
    Scale.linear ( height - padding.bottom, padding.top ) ( toFloat adjustedMax, toFloat adjustedMin )


{-| Y axis (position). Labels are shown 1-indexed as P1, P5, P10…, drawn by passing
tick settings to the shared `yAxis` wrapper (the scale is 0-indexed, so labels add +1).
-}
positionAxis : Dimensions -> ContinuousScale Float -> Svg msg
positionAxis dimensions yScale =
    let
        ( domainMax, _ ) =
            Scale.domain yScale

        labelPositions =
            1
                :: (List.range 1 ((round domainMax // 5) + 1) |> List.map (\i -> i * 5))
                |> List.filter (\v -> v - 1 <= round domainMax)

        tickValues_ =
            labelPositions |> List.map (\label -> toFloat (label - 1))
    in
    yAxis dimensions
        [ ticks tickValues_
        , tickSizeOuter 0
        , tickSizeInner 5
        , tickFormat (round >> (+) 1 >> String.fromInt)
        ]
        yScale


{-| Converts a `PositionSeries` into the shared renderer `renderLine`'s input and
draws one line. The vertical quantity is position.
-}
positionLine : Scales -> PositionSeries -> Svg msg
positionLine scales series =
    renderLine scales
        { color = series.color
        , emphasis = series.emphasis
        , label = series.carNumber
        , points = series.points |> List.map (\p -> ( p.lap, p.position ))
        }
