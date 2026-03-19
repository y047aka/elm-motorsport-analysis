module Motorsport.Widget.Compare.PositionProgression exposing (view)

import Axis exposing (tickFormat, tickPadding, tickSizeInner, tickSizeOuter, ticks)
import Css exposing (Color)
import Css.Extra
import Css.Global exposing (descendants, each)
import Html.Styled as Html exposing (Html)
import List.Extra
import Motorsport.Clock as Clock
import Motorsport.Manufacturer as Manufacturer
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget as Widget
import Path.Styled as Path
import Scale exposing (ContinuousScale)
import Shape
import SortedList
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, line, svg)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Transform(..))


view : { width : Float, height : Float } -> Clock.Model -> ViewModel -> List ViewModelItem -> Html msg
view size clock viewModel selectedCars =
    case buildClassProgressionData clock viewModel selectedCars of
        Ok series ->
            positionProgressionChart size series

        Err message ->
            Widget.emptyState message


buildClassProgressionData : Clock.Model -> ViewModel -> List ViewModelItem -> Result String (List PositionSeries)
buildClassProgressionData clock viewModel selectedCars =
    let
        lapThreshold =
            calculateLapThreshold clock viewModel

        selectedCarNumbers =
            selectedCars |> List.map (.metadata >> .carNumber)

        classCars : List ViewModelItem
        classCars =
            viewModel.itemsByClass
                |> List.Extra.find (\( class_, _ ) -> Just class_ == (selectedCars |> List.head |> Maybe.map (.metadata >> .class)))
                |> Maybe.map (\( _, cars ) -> SortedList.toList cars)
                |> Maybe.withDefault []

        series =
            classCars
                |> List.map
                    (\item ->
                        let
                            carNumber =
                                item.metadata.carNumber
                        in
                        { points = buildPositionPoints lapThreshold item
                        , color = Manufacturer.toColorWithFallback item.metadata
                        , isSelected = List.member carNumber selectedCarNumbers
                        }
                    )
                |> List.filter (\item -> List.length item.points >= 2)
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
    , isSelected : Bool
    }


chartPadding : Float
chartPadding =
    15


chartPaddingLeft : Float
chartPaddingLeft =
    chartPadding + 15


chartPaddingBottom : Float
chartPaddingBottom =
    chartPadding + 15


positionHistoryWindowMillis : Int
positionHistoryWindowMillis =
    3 * 60 * 60 * 1000


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


positionProgressionChart : { width : Float, height : Float } -> List PositionSeries -> Html msg
positionProgressionChart size series =
    let
        allPoints =
            series |> List.concatMap .points
    in
    svg
        [ SvgAttr.width "100%"
        , viewBox 0 0 size.width size.height
        ]
        ([ xGridLines size allPoints
         , xAxis size allPoints
         , yAxis size allPoints
         ]
            ++ (series |> List.map (renderPositionLine size allPoints))
        )


buildPositionPoints : Int -> ViewModelItem -> List PositionPoint
buildPositionPoints lapThreshold item =
    item.history
        |> List.filter (\lap -> lap.lap >= lapThreshold)
        |> List.filterMap
            (\lap ->
                lap.position |> Maybe.map (\pos -> { lapNumber = lap.lap, position = pos })
            )


xScale : { width : Float, height : Float } -> List PositionPoint -> ContinuousScale Float
xScale size positions =
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
    Scale.linear ( chartPaddingLeft, size.width - chartPadding ) ( toFloat minLap, toFloat maxLap )


yScale : { width : Float, height : Float } -> List PositionPoint -> ContinuousScale Float
yScale size positions =
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
    Scale.linear ( size.height - chartPaddingBottom, chartPadding ) ( toFloat adjustedMax, toFloat adjustedMin )


xGridLines : { width : Float, height : Float } -> List PositionPoint -> Svg msg
xGridLines size positions =
    let
        lapNumbers =
            positions |> List.map .lapNumber

        minLap =
            List.minimum lapNumbers |> Maybe.withDefault 1

        maxLap =
            List.maximum lapNumbers |> Maybe.withDefault 1

        gridLaps =
            List.range minLap maxLap |> List.filter (\l -> modBy 5 l == 0)

        top =
            chartPadding

        bottom =
            size.height - chartPaddingBottom
    in
    g [] <|
        List.map
            (\lap ->
                let
                    x =
                        toFloat lap |> Scale.convert (xScale size positions)
                in
                line
                    [ SvgAttr.x1 (String.fromFloat x)
                    , SvgAttr.x2 (String.fromFloat x)
                    , SvgAttr.y1 (String.fromFloat top)
                    , SvgAttr.y2 (String.fromFloat bottom)
                    , SvgAttr.css
                        [ Css.property "stroke" "#333"
                        , Css.Extra.strokeWidth 1
                        ]
                    ]
                    []
            )
            gridLaps


xAxis : { width : Float, height : Float } -> List PositionPoint -> Svg msg
xAxis size positions =
    let
        lapNumbers =
            positions |> List.map .lapNumber

        minLap =
            List.minimum lapNumbers |> Maybe.withDefault 1

        maxLap =
            List.maximum lapNumbers |> Maybe.withDefault 1

        allLaps =
            List.range minLap maxLap |> List.map toFloat

        axis =
            fromUnstyled <|
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
                    (xScale size positions)
    in
    g
        [ SvgAttr.css
            [ descendants
                [ Css.Global.typeSelector "text"
                    [ Css.fill (Css.hsl 0 0 0.7)
                    , Css.fontSize (Css.px 11)
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
        , transform [ Translate 0 (size.height - chartPaddingBottom) ]
        ]
        [ axis ]


yAxis : { width : Float, height : Float } -> List PositionPoint -> Svg msg
yAxis size positions =
    let
        scale =
            yScale size positions

        ( domainMax, _ ) =
            Scale.domain scale

        -- ラベルは1-indexed（1位、5位、10位...）、スケールは0-indexed
        labelPositions =
            1
                :: (List.range 1 ((round domainMax // 5) + 1) |> List.map (\i -> i * 5))
                |> List.filter (\v -> v - 1 <= round domainMax)

        tickValues_ =
            labelPositions |> List.map (\label -> toFloat (label - 1))

        axis =
            fromUnstyled <|
                Axis.left
                    [ ticks tickValues_
                    , tickSizeOuter 0
                    , tickSizeInner 5
                    , tickFormat (round >> (+) 1 >> String.fromInt)
                    ]
                    scale
    in
    g
        [ SvgAttr.css
            [ descendants
                [ Css.Global.typeSelector "text"
                    [ Css.fill (Css.hsl 0 0 0.7)
                    , Css.fontSize (Css.px 11)
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


renderPositionLine : { width : Float, height : Float } -> List PositionPoint -> PositionSeries -> Svg msg
renderPositionLine size allPoints series =
    let
        dataPoints =
            series.points
                |> List.map
                    (\{ lapNumber, position } ->
                        ( lapNumber
                            |> toFloat
                            |> Scale.convert (xScale size allPoints)
                        , position
                            |> toFloat
                            |> Scale.convert (yScale size allPoints)
                        )
                    )

        linePath =
            dataPoints
                |> List.map Just
                |> Shape.line Shape.linearCurve

        strokeWidth =
            if series.isSelected then
                "2"

            else
                "1.2"

        opacity =
            if series.isSelected then
                "1"

            else
                "0.4"

        lineAttributes =
            [ SvgAttr.stroke series.color.value
            , SvgAttr.strokeWidth strokeWidth
            , SvgAttr.strokeOpacity opacity
            , SvgAttr.fill "none"
            ]

        lastPointElement =
            if series.isSelected then
                dataPoints
                    |> List.Extra.last
                    |> Maybe.map
                        (\( x, y ) ->
                            circle
                                [ InPx.cx x
                                , InPx.cy y
                                , InPx.r 3.0
                                , SvgAttr.css [ Css.fill series.color ]
                                ]
                                []
                        )
                    |> Maybe.withDefault (g [] [])

            else
                g [] []
    in
    g []
        [ Path.element linePath lineAttributes
        , lastPointElement
        ]
