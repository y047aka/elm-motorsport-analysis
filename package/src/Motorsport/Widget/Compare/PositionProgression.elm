module Motorsport.Widget.Compare.PositionProgression exposing (lapRange, view)

import Axis exposing (tickFormat, tickSizeInner, tickSizeOuter, ticks)
import Css exposing (Color)
import Html.Styled exposing (Html)
import List.Extra
import Motorsport.Chart.Common exposing (Dimensions, Emphasis(..), Scales, axisPadding, lapAxis, lapGridLines, renderLine, sortForDrawing, svg, xContinuousScale, yAxis)
import Motorsport.Class exposing (Class)
import Motorsport.Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.ViewModel exposing (ViewModel)
import Motorsport.ViewModel.LapHistory as LapHistory
import Motorsport.ViewModel.Standings as Standings exposing (Entry, Standings)
import Motorsport.Widget as Widget
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg)


view : { width : Float, height : Float } -> ViewModel -> { class : Class, highlighted : List String } -> Html msg
view size viewModel target =
    case buildClassProgressionData viewModel target of
        Ok series ->
            positionProgressionChart size series

        Err message ->
            Widget.emptyState message


{-| The lap-number range `(minLap, maxLap)` the position-history chart currently
draws. Shared so the sparkline can be drawn over the same range (X axis). When there
is nothing to display, returns `Nothing`. Computed with the same threshold (the
recent window) and the same point-extraction condition as the chart itself.
-}
lapRange : ViewModel -> Class -> Maybe ( Int, Int )
lapRange viewModel class =
    let
        lapNumbers =
            classPositionPoints viewModel class
                |> List.concatMap (Tuple.second >> List.map .lapNumber)
    in
    Maybe.map2 Tuple.pair (List.minimum lapNumbers) (List.maximum lapNumbers)


classEntriesOf : Standings -> Class -> List Entry
classEntriesOf standings class =
    Standings.toClassList standings
        |> List.Extra.find (\( classInfo, _ ) -> classInfo.class == class)
        |> Maybe.map Tuple.second
        |> Maybe.withDefault []


{-| Builds the "position points past the threshold" for each car in the class,
keeping only cars with two or more points. Centralizes the point-extraction
condition here so the chart itself and `lapRange` share the same X axis.
-}
classPositionPoints : ViewModel -> Class -> List ( Entry, List PositionPoint )
classPositionPoints ({ standings, lapHistory } as viewModel) class =
    let
        lapThreshold =
            calculateLapThreshold viewModel
    in
    classEntriesOf standings class
        |> List.map (\item -> ( item, buildPositionPoints lapThreshold (LapHistory.get item.metadata.carNumber lapHistory) ))
        |> List.filter (\( _, points ) -> List.length points >= 2)


buildClassProgressionData : ViewModel -> { class : Class, highlighted : List String } -> Result String (List PositionSeries)
buildClassProgressionData viewModel { class, highlighted } =
    let
        series =
            classPositionPoints viewModel class
                |> List.map
                    (\( item, points ) ->
                        { points = points
                        , color = Manufacturer.toColorWithFallback item.metadata
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


calculateLapThreshold : ViewModel -> Int
calculateLapThreshold { standings, lapHistory } =
    let
        currentRaceTime =
            Standings.elapsed standings

        timeThreshold =
            max 0 (currentRaceTime - positionHistoryWindowMillis)
    in
    Standings.leader standings
        |> Maybe.map (\l -> LapHistory.get l.metadata.carNumber lapHistory)
        |> Maybe.andThen (List.Extra.find (\lap -> lap.elapsed >= timeThreshold))
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
