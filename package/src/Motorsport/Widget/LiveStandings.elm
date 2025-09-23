module Motorsport.Widget.LiveStandings exposing (DetailProps, ListProps, detailView, view)

import Axis exposing (tickCount, tickFormat, tickSizeInner, tickSizeOuter)
import Css exposing (Color, after, backgroundColor, hover, num, property, px, width)
import Css.Extra
import Css.Global exposing (descendants, each)
import Data.Series as Series
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, img, li, text, ul)
import Html.Styled.Attributes exposing (class, css, src)
import Html.Styled.Events exposing (onClick)
import List.Extra
import Motorsport.Car as Car
import Motorsport.Class as Class
import Motorsport.Clock as Clock
import Motorsport.Gap as Gap
import Motorsport.Lap.Performance as Performance
import Motorsport.Leaderboard as Leaderboard
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


type alias ListProps msg =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , onSelectCar : ViewModelItem -> msg
    }


type alias DetailProps =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , clock : Clock.Model
    , selectedCar : Maybe ViewModelItem
    }


view : ListProps msg -> Html msg
view props =
    let
        headerTitle =
            props.eventSummary.name ++ " (" ++ String.fromInt props.eventSummary.season ++ ")"

        carList =
            props.viewModel.items
                |> SortedList.toList
                |> List.map (carRow props.eventSummary.season props.onSelectCar)
    in
    Widget.container headerTitle <|
        ul [ class "list" ] carList


carRow : Int -> (ViewModelItem -> msg) -> ViewModelItem -> Html msg
carRow season onSelect item =
    li
        [ onClick (onSelect item)
        , class "list-row p-2 grid-cols-[20px_30px_1fr_auto] items-center gap-2"
        , css
            [ after [ property "border-color" "hsl(0 0% 100% / 0.1)" ]
            , property "cursor" "pointer"
            , property "transition" "background-color 0.2s ease"
            , hover [ property "background-color" "hsl(0 0% 100% / 0.05)" ]
            ]
        ]
        [ div [ class "text-center text-xs" ] [ text (String.fromInt item.position) ]
        , div
            [ class "py-1 text-center text-xs font-bold rounded"
            , css [ backgroundColor (Class.toHexColor season item.metadata.class) ]
            ]
            [ text item.metadata.carNumber ]
        , div []
            [ div [ class "text-xs" ] [ text item.metadata.team ]
            , div [ class "text-xs opacity-60" ]
                [ text (item.currentDriver |> Maybe.map .name |> Maybe.withDefault "") ]
            ]
        , div [ class "text-xs text-right" ]
            [ text (Gap.toString item.timing.interval) ]
        ]


detailView : DetailProps -> Html msg
detailView props =
    let
        ( title, body ) =
            case props.selectedCar of
                Nothing ->
                    ( "Car Details"
                    , Widget.emptyState "Select a car from the standings to view details"
                    )

                Just item ->
                    ( item.metadata.carNumber ++ " - " ++ item.metadata.team
                    , div
                        [ css
                            [ property "display" "grid"
                            , property "row-gap" "16px"
                            ]
                        ]
                        [ detailHeader props.eventSummary.season item
                        , detailBody props item
                        ]
                    )
    in
    Widget.container title body


detailHeader : Int -> ViewModelItem -> Html msg
detailHeader season item =
    let
        carImage carNumber =
            case Series.carImageUrl_Wec season carNumber of
                Just url ->
                    img [ src url, css [ width (px 100) ] ] []

                Nothing ->
                    text ""
    in
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto auto 1fr"
            , property "align-items" "center"
            , property "column-gap" "10px"
            , property "padding-bottom" "12px"
            , property "border-bottom" "1px solid hsl(0 0% 100% / 0.1)"
            ]
        ]
        [ Leaderboard.viewCarNumberColumn_Wec season item.metadata
        , Leaderboard.viewDriverAndTeamColumn_Wec item
        , carImage item.metadata.carNumber
        ]


detailBody : DetailProps -> ViewModelItem -> Html msg
detailBody { eventSummary, viewModel, clock } item =
    let
        analysis =
            let
                laps =
                    item.history
            in
            { fastestLapTime = [ laps ] |> Performance.findFastest |> Maybe.map .time |> Maybe.withDefault 0
            , slowestLapTime = [ laps ] |> Performance.findSlowest |> Maybe.map .time |> Maybe.withDefault 0
            , sector_1_fastest = [ laps ] |> Performance.findFastestBy .sector_1 |> Maybe.withDefault 0
            , sector_2_fastest = [ laps ] |> Performance.findFastestBy .sector_2 |> Maybe.withDefault 0
            , sector_3_fastest = [ laps ] |> Performance.findFastestBy .sector_3 |> Maybe.withDefault 0
            , miniSectorFastest = Performance.calculateMiniSectorFastest [ laps ]
            }
    in
    div
        [ css
            [ property "display" "grid"
            , property "row-gap" "20px"
            ]
        ]
        [ div
            [ css
                [ property "display" "grid"
                , property "grid-template-columns" "1fr 1fr"
                , property "column-gap" "12px"
                ]
            ]
            [ div []
                [ Html.div [ class "text-xs opacity-60" ] [ text "Current Lap" ]
                , (case ( eventSummary.season, eventSummary.name ) of
                    ( 2025, "24 Hours of Le Mans" ) ->
                        Leaderboard.viewCurrentLapColumn_LeMans24h

                    _ ->
                        Leaderboard.viewCurrentLapColumn_Wec
                  )
                    analysis
                    item
                ]
            , div []
                [ Html.div [ class "text-xs opacity-60" ] [ text "Last Lap" ]
                , (case ( eventSummary.season, eventSummary.name ) of
                    ( 2025, "24 Hours of Le Mans" ) ->
                        Leaderboard.viewLastLapColumn_LeMans24h

                    _ ->
                        Leaderboard.viewLastLapColumn_Wec
                  )
                    analysis
                    item.lastLap
                ]
            ]
        , positionProgressionSection clock viewModel item.metadata
        ]



-- POSITION PROGRESSION CHART


type alias PositionPoint =
    { lapNumber : Int
    , position : Int
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
            [ property "display" "grid"
            , property "row-gap" "8px"
            , property "padding-top" "12px"
            , property "border-top" "1px solid hsl(0 0% 100% / 0.1)"
            ]
        ]
        [ Html.div [ class "text-sm font-semibold" ] [ text "Position Progression" ]
        , chartBody
        ]


type alias PositionSeries =
    { points : List PositionPoint
    , color : Color
    , isSelected : Bool
    }


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
        x_ =
            xScale allPoints

        y_ =
            yScale allPoints

        dataPoints =
            series.points
                |> List.map
                    (\{ lapNumber, position } ->
                        ( lapNumber
                            |> toFloat
                            |> Scale.convert x_
                        , position
                            |> toFloat
                            |> Scale.convert y_
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
