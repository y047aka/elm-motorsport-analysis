module Motorsport.Widget.CarDetail.PositionProgression exposing (view)

import Axis exposing (tickFormat, tickSizeInner, tickSizeOuter, ticks)
import Html exposing (Html)
import List.Extra
import Motorsport.Analysis.Rivals as Rivals exposing (Rivals)
import Motorsport.Chart.Common exposing (Dimensions, Emphasis(..), Scales, axisPadding, lapAxis, lapGridLines, renderLine, sortForDrawing, svg, xContinuousScale, yAxis)
import Motorsport.Lap exposing (Lap)
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Wec.Class exposing (Class)
import Motorsport.Widget as Widget
import Scale exposing (ContinuousScale)
import Svg exposing (Svg)


{-| The whole class over the given laps, the cars of `rivals` picked out of it.

Unlike the other charts of the panel, the population is the class rather than
the rivals: a car's position only means anything against everyone it could have
gained or lost one to.

-}
view : ( Int, Int ) -> Snapshot -> Rivals -> Html msg
view range snapshot rivals =
    case buildClassProgressionData range snapshot rivals of
        Ok series ->
            positionProgressionChart consolidated series

        Err message ->
            Widget.emptyState message


{-| The size the panel's full-width charts share.
-}
consolidated : { width : Float, height : Float }
consolidated =
    { width = 1000, height = 250 }


{-| Builds the position points inside the range for each car in the class,
keeping only cars with two or more points.
-}
classPositionPoints : ( Int, Int ) -> Snapshot -> Class -> List ( CarAt, List PositionPoint )
classPositionPoints range snapshot class =
    let
        lapHistory =
            Snapshot.lapHistory snapshot
    in
    Snapshot.inClass class snapshot
        |> List.map (\item -> ( item, buildPositionPoints range (LapHistory.get item.metadata.carNumber lapHistory) ))
        |> List.filter (\( _, points ) -> List.length points >= 2)


buildClassProgressionData : ( Int, Int ) -> Snapshot -> Rivals -> Result String (List PositionSeries)
buildClassProgressionData range snapshot rivals =
    let
        highlighted =
            Rivals.nearest 1 rivals |> List.map (.metadata >> .carNumber)

        series =
            classPositionPoints range snapshot (Rivals.focused rivals).metadata.class
                |> List.map
                    (\( item, points ) ->
                        { points = points
                        , color = item.metadata.manufacturer.color
                        , carNumber = item.metadata.carNumber
                        , emphasis =
                            if List.member item.metadata.carNumber highlighted then
                                Focused

                            else
                                Muted
                        }
                    )
    in
    if List.isEmpty series then
        Err "Lap chart will appear as more laps are completed."

    else
        Ok series


type alias PositionPoint =
    { lapNumber : Int
    , position : Int
    }


type alias PositionSeries =
    { points : List PositionPoint
    , color : String
    , carNumber : String
    , emphasis : Emphasis
    }


{-| The lap-number range `(minLap, maxLap)` the point series spans. `(1, 1)` when empty.
-}
lapExtent : List PositionPoint -> ( Int, Int )
lapExtent positions =
    let
        laps =
            positions |> List.map .lapNumber
    in
    ( List.minimum laps |> Maybe.withDefault 1
    , List.maximum laps |> Maybe.withDefault 1
    )


positionProgressionChart : { width : Float, height : Float } -> List PositionSeries -> Html msg
positionProgressionChart size series =
    let
        dimensions =
            { width = size.width
            , height = size.height
            , padding = axisPadding
            }

        allPoints =
            series |> List.concatMap .points

        lapRange_ =
            lapExtent allPoints

        ( minLap, maxLap ) =
            lapRange_

        scales =
            { xScale = xContinuousScale dimensions ( toFloat minLap, toFloat maxLap )
            , yScale = yContinuousScale dimensions allPoints
            }

        -- Stack back-to-front: Muted (back) → Related → Focused (front).
        orderedSeries =
            sortForDrawing .emphasis (.points >> List.Extra.last >> Maybe.map .position) series
    in
    svg size
        ([ lapGridLines dimensions scales.xScale lapRange_
         , lapAxis dimensions scales.xScale lapRange_
         , positionAxis dimensions scales.yScale
         ]
            ++ List.map (positionLine scales) orderedSeries
        )


buildPositionPoints : ( Int, Int ) -> List Lap -> List PositionPoint
buildPositionPoints ( minLap, maxLap ) history =
    history
        |> List.filter (\lap -> minLap <= lap.lap && lap.lap <= maxLap)
        |> List.filterMap
            (\lap ->
                lap.position |> Maybe.map (\pos -> { lapNumber = lap.lap, position = pos })
            )


yContinuousScale : Dimensions -> List PositionPoint -> ContinuousScale Float
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
        , points = series.points |> List.map (\p -> ( p.lapNumber, p.position ))
        }
