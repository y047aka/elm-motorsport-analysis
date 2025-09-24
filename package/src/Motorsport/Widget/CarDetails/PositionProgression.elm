module Motorsport.Widget.CarDetails.PositionProgression exposing (positionProgressionSection)

import Axis exposing (tickCount, tickFormat, tickSizeInner, tickSizeOuter)
import Css exposing (Color, num)
import Css.Extra
import Css.Global exposing (descendants, each)
import Html.Styled as Html exposing (Html, div, text)
import Html.Styled.Attributes exposing (class, css)
import List.Extra
import Motorsport.Car as Car
import Motorsport.Clock as Clock
import Motorsport.Manufacturer as Manufacturer
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget as Widget
import Path.Styled as Path
import Scale exposing (ContinuousScale)
import Shape
import SortedList
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, svg)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Transform(..))


positionProgressionSection : Clock.Model -> ViewModel -> Car.Metadata -> Html msg
positionProgressionSection clock viewModel metadata =
    let
        lapThreshold =
            calculateLapThreshold clock viewModel

        classCars : List ViewModelItem
        classCars =
            viewModel.itemsByClass
                |> List.Extra.find (\( class_, _ ) -> class_ == metadata.class)
                |> Maybe.map (\( _, cars ) -> SortedList.toList cars)
                |> Maybe.withDefault []

        candidates =
            classCars
                |> List.map
                    (\item ->
                        { carNumber = item.metadata.carNumber
                        , points = buildPositionPoints lapThreshold item
                        , color = Manufacturer.toColorWithFallback item.metadata
                        }
                    )

        seriesResult : Result String (List PositionSeries)
        seriesResult =
            case candidates |> List.Extra.find (\candidate -> candidate.carNumber == metadata.carNumber) of
                Nothing ->
                    Err "Selected car data is unavailable."

                Just selectedCandidate ->
                    if List.length selectedCandidate.points < 2 then
                        Err "Position chart will appear as more laps are completed."

                    else
                        candidates
                            |> List.filterMap
                                (\candidate ->
                                    if List.length candidate.points < 2 then
                                        Nothing

                                    else
                                        Just
                                            { points = candidate.points
                                            , color = candidate.color
                                            , isSelected = candidate.carNumber == metadata.carNumber
                                            }
                                )
                            |> Ok

        chartBody =
            case seriesResult of
                Ok series ->
                    positionProgressionChart series

                Err message ->
                    Widget.emptyState message
    in
    div
        [ css
            [ Css.property "display" "grid"
            , Css.property "row-gap" "8px"
            , Css.property "padding-top" "12px"
            , Css.property "border-top" "1px solid hsl(0 0% 100% / 0.1)"
            ]
        ]
        [ Html.div [ class "text-sm font-semibold" ] [ text "Position Progression" ]
        , chartBody
        ]


type alias PositionPoint =
    { lapNumber : Int
    , position : Int
    }


type alias PositionSeries =
    { points : List PositionPoint
    , color : Color
    , isSelected : Bool
    }


chartWidth : Float
chartWidth =
    320


chartHeight : Float
chartHeight =
    180


chartPadding : Float
chartPadding =
    15


chartPaddingLeft : Float
chartPaddingLeft =
    chartPadding + 35


chartPaddingBottom : Float
chartPaddingBottom =
    chartPadding + 15


positionHistoryWindowMillis : Int
positionHistoryWindowMillis =
    60 * 60 * 1000


calculateLapThreshold : Clock.Model -> ViewModel -> Int
calculateLapThreshold clock viewModel =
    let
        currentRaceTime =
            Clock.getElapsed clock

        timeThreshold =
            max 0 (currentRaceTime - positionHistoryWindowMillis)
    in
    SortedList.head viewModel.items
        |> Maybe.map .history
        |> Maybe.andThen (List.Extra.find (\lap -> lap.elapsed >= timeThreshold))
        |> Maybe.map .lap
        |> Maybe.withDefault 1


positionProgressionChart : List PositionSeries -> Html msg
positionProgressionChart series =
    let
        allPoints =
            series |> List.concatMap .points
    in
    svg
        [ InPx.width chartWidth
        , InPx.height chartHeight
        , viewBox 0 0 chartWidth chartHeight
        ]
        ([ xAxis allPoints
         , yAxis allPoints
         ]
            ++ (series |> List.map (renderPositionLine allPoints))
        )


buildPositionPoints : Int -> ViewModelItem -> List PositionPoint
buildPositionPoints lapThreshold item =
    item.history
        |> List.filter (\lap -> lap.lap >= lapThreshold)
        |> List.filterMap
            (\lap ->
                lap.position |> Maybe.map (\pos -> { lapNumber = lap.lap, position = pos })
            )


xScale : List PositionPoint -> ContinuousScale Float
xScale positions =
    let
        ( minLap, maxLap ) =
            positions
                |> List.map .lapNumber
                |> (\laps ->
                        ( List.minimum laps |> Maybe.withDefault 1
                        , List.maximum laps |> Maybe.withDefault 1
                        )
                   )
    in
    Scale.linear ( chartPaddingLeft, chartWidth - chartPadding ) ( toFloat minLap, toFloat maxLap )


yScale : List PositionPoint -> ContinuousScale Float
yScale positions =
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
            max 1 (minPos - paddingY)

        adjustedMax =
            maxPos + paddingY
    in
    Scale.linear ( chartHeight - chartPaddingBottom, chartPadding ) ( toFloat adjustedMax, toFloat adjustedMin )


xAxis : List PositionPoint -> Svg msg
xAxis positions =
    let
        axis =
            fromUnstyled <|
                Axis.bottom
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 3
                    , tickFormat (round >> String.fromInt)
                    ]
                    (xScale positions)
    in
    g
        [ SvgAttr.css
            [ descendants
                [ Css.Global.typeSelector "text"
                    [ Css.fill (Css.hsl 0 0 0.7)
                    , Css.fontSize (Css.px 9)
                    ]
                , each
                    [ Css.Global.typeSelector "line"
                    , Css.Global.typeSelector "path"
                    ]
                    [ Css.Extra.strokeWidth 1
                    , Css.property "stroke" "#555"
                    ]
                ]
            ]
        , transform [ Translate 0 (chartHeight - chartPaddingBottom) ]
        ]
        [ axis ]


yAxis : List PositionPoint -> Svg msg
yAxis positions =
    let
        allPositions =
            positions |> List.map .position

        positionRange =
            (List.maximum allPositions |> Maybe.withDefault 1) - (List.minimum allPositions |> Maybe.withDefault 1) + 1

        tickCount_ =
            min 5 (max 2 positionRange)

        axis =
            fromUnstyled <|
                Axis.left
                    [ tickCount tickCount_
                    , tickSizeOuter 0
                    , tickSizeInner 5
                    , tickFormat (round >> String.fromInt)
                    ]
                    (yScale positions)
    in
    g
        [ SvgAttr.css
            [ descendants
                [ Css.Global.typeSelector "text"
                    [ Css.fill (Css.hsl 0 0 0.7)
                    , Css.fontSize (Css.px 9)
                    ]
                , each
                    [ Css.Global.typeSelector "line"
                    , Css.Global.typeSelector "path"
                    ]
                    [ Css.Extra.strokeWidth 1
                    , Css.property "stroke" "#555"
                    ]
                ]
            ]
        , transform [ Translate chartPaddingLeft 0 ]
        ]
        [ axis ]


renderPositionLine : List PositionPoint -> PositionSeries -> Svg msg
renderPositionLine allPoints series =
    let
        dataPoints =
            series.points
                |> List.map
                    (\{ lapNumber, position } ->
                        ( lapNumber
                            |> toFloat
                            |> Scale.convert (xScale allPoints)
                        , position
                            |> toFloat
                            |> Scale.convert (yScale allPoints)
                        )
                    )

        totalPoints =
            List.length dataPoints

        linePath =
            dataPoints
                |> List.map Just
                |> Shape.line Shape.linearCurve

        strokeWidth =
            if series.isSelected then
                "1.5"

            else
                "1"

        baseAttributes =
            [ SvgAttr.stroke series.color.value
            , SvgAttr.strokeWidth strokeWidth
            , SvgAttr.fill "none"
            ]

        lineAttributes =
            if series.isSelected then
                baseAttributes

            else
                SvgAttr.strokeOpacity "0.4" :: baseAttributes

        pointElements =
            dataPoints
                |> List.indexedMap
                    (\index ( x, y ) ->
                        let
                            radius =
                                case ( series.isSelected, index == totalPoints - 1 ) of
                                    ( True, True ) ->
                                        2.5

                                    ( True, False ) ->
                                        1.5

                                    _ ->
                                        0.8
                        in
                        circle
                            [ InPx.cx x
                            , InPx.cy y
                            , InPx.r radius
                            , SvgAttr.css
                                [ Css.fill series.color
                                , if series.isSelected then
                                    Css.batch []

                                  else
                                    Css.opacity (num 0.4)
                                ]
                            ]
                            []
                    )
    in
    g []
        (Path.element linePath lineAttributes
            :: pointElements
        )
