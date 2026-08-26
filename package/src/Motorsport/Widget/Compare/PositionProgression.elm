module Motorsport.Widget.Compare.PositionProgression exposing (lapRange, view)

import Axis exposing (tickFormat, tickSizeInner, tickSizeOuter, ticks)
import Css exposing (Color)
import Html.Styled exposing (Html)
import List.Extra
import Motorsport.Chart.Common exposing (Dimensions, Emphasis(..), Scales, axisPadding, lapAxis, lapGridLines, renderLine, sortForDrawing, svg, xContinuousScale, yAxis)
import Motorsport.Instant as Instant
import Motorsport.Lap exposing (Lap)
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Wec.Class exposing (Class)
import Motorsport.Widget as Widget
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg)


view : { width : Float, height : Float } -> Snapshot -> { class : Class, highlighted : List String } -> Html msg
view size snapshot target =
    case buildClassProgressionData snapshot target of
        Ok series ->
            positionProgressionChart size series

        Err message ->
            Widget.emptyState message


{-| The lap-number range `(minLap, maxLap)` the position-history chart currently
draws. Shared so the sparkline can be drawn over the same range (X axis). When there
is nothing to display, returns `Nothing`. Computed with the same threshold (the
recent window) and the same point-extraction condition as the chart itself.
-}
lapRange : Snapshot -> Class -> Maybe ( Int, Int )
lapRange snapshot class =
    let
        lapNumbers =
            classPositionPoints snapshot class
                |> List.concatMap (Tuple.second >> List.map .lapNumber)
    in
    Maybe.map2 Tuple.pair (List.minimum lapNumbers) (List.maximum lapNumbers)


{-| Builds the "position points past the threshold" for each car in the class,
keeping only cars with two or more points. Centralizes the point-extraction
condition here so the chart itself and `lapRange` share the same X axis.
-}
classPositionPoints : Snapshot -> Class -> List ( CarAt, List PositionPoint )
classPositionPoints snapshot class =
    let
        lapThreshold =
            calculateLapThreshold snapshot

        lapHistory =
            Snapshot.lapHistory snapshot
    in
    Snapshot.inClass class snapshot
        |> List.map (\item -> ( item, buildPositionPoints lapThreshold (LapHistory.get item.metadata.carNumber lapHistory) ))
        |> List.filter (\( _, points ) -> List.length points >= 2)


buildClassProgressionData : Snapshot -> { class : Class, highlighted : List String } -> Result String (List PositionSeries)
buildClassProgressionData snapshot { class, highlighted } =
    let
        series =
            classPositionPoints snapshot class
                |> List.map
                    (\( item, points ) ->
                        { points = points
                        , color = item.metadata.manufacturer.chartColor
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
    , color : Color
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


positionHistoryWindowMillis : Int
positionHistoryWindowMillis =
    6 * 60 * 60 * 1000


calculateLapThreshold : Snapshot -> Int
calculateLapThreshold snapshot =
    let
        currentRaceTime =
            Snapshot.elapsed snapshot

        timeThreshold =
            Instant.subtract positionHistoryWindowMillis currentRaceTime
    in
    Snapshot.leader snapshot
        |> Maybe.map (\l -> LapHistory.get l.metadata.carNumber (Snapshot.lapHistory snapshot))
        |> Maybe.andThen (List.Extra.find (\lap -> Instant.compare lap.elapsed timeThreshold /= LT))
        |> Maybe.map .lap
        |> Maybe.withDefault 1


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


buildPositionPoints : Int -> List Lap -> List PositionPoint
buildPositionPoints lapThreshold history =
    history
        |> List.filter (\lap -> lap.lap >= lapThreshold)
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
