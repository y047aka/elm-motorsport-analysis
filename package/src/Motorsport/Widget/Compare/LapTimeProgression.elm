module Motorsport.Widget.Compare.LapTimeProgression exposing (view)

import Axis exposing (tickCount, tickFormat, tickPadding, tickSizeInner, tickSizeOuter, ticks)
import Css exposing (Color)
import Css.Extra
import Css.Global exposing (descendants, each)
import Html.Styled exposing (Html)
import List.Extra
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration
import Motorsport.Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Standings exposing (Standings, StandingsEntry)
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



-- Chart configuration


padding : Float
padding =
    15


paddingLeft : Float
paddingLeft =
    padding + 50


paddingBottom : Float
paddingBottom =
    padding + 15


type alias LapTimeSeries =
    { carNumber : String
    , laps : List Lap
    , color : Color
    , isSelected : Bool
    }


type alias ClassProgressionData =
    { series : List LapTimeSeries }


view : { width : Float, height : Float } -> Clock.Model -> Standings -> List StandingsEntry -> Html msg
view size clock viewModel selectedCars =
    case buildClassProgressionData clock viewModel selectedCars of
        Err message ->
            Widget.emptyState message

        Ok classData ->
            lapTimeProgressionChart size classData.series


buildClassProgressionData : Clock.Model -> Standings -> List StandingsEntry -> Result String ClassProgressionData
buildClassProgressionData clock viewModel selectedCars =
    let
        selectedCarNumbers =
            selectedCars |> List.map (.metadata >> .carNumber)

        carsInClass : List StandingsEntry
        carsInClass =
            viewModel.entriesByClass
                |> List.Extra.find (\( class_, _ ) -> Just class_ == (selectedCars |> List.head |> Maybe.map (.metadata >> .class)))
                |> Maybe.map (\( _, cars ) -> SortedList.toList cars)
                |> Maybe.withDefault []

        series : List LapTimeSeries
        series =
            carsInClass
                |> List.map
                    (\item ->
                        let
                            carNumber =
                                item.metadata.carNumber
                        in
                        { carNumber = carNumber
                        , laps = extractLapDataForCar clock item.history
                        , color = Manufacturer.toColorWithFallback item.metadata
                        , isSelected = List.member carNumber selectedCarNumbers
                        }
                    )
                |> List.filter (\item -> List.length item.laps >= 2)
    in
    if List.isEmpty series then
        Err "Lap chart will appear as more laps are completed."

    else
        Ok { series = series }


extractLapDataForCar : Clock.Model -> List Lap -> List Lap
extractLapDataForCar clock laps =
    let
        currentRaceTime =
            Clock.getElapsed clock

        timeThreshold =
            currentRaceTime - (2 * 60 * 60 * 1000)
    in
    laps
        |> List.filter (\lap -> timeThreshold <= lap.elapsed && lap.elapsed <= currentRaceTime)


filterOutlierLaps : List Lap -> List Lap
filterOutlierLaps laps =
    let
        fastestTime =
            laps
                |> List.map .time
                |> List.minimum
                |> Maybe.withDefault 999999

        threshold =
            toFloat fastestTime * 1.1 |> round
    in
    laps
        |> List.filter (\lap -> lap.time <= threshold)



-- Scales


xScale : { width : Float, height : Float } -> List Lap -> ContinuousScale Float
xScale size laps =
    let
        ( minTime, maxTime ) =
            laps
                |> List.map .elapsed
                |> (\ts ->
                        ( List.minimum ts |> Maybe.withDefault 0
                        , List.maximum ts |> Maybe.withDefault 0
                        )
                   )
    in
    Scale.linear ( paddingLeft, size.width - padding ) ( toFloat minTime, toFloat maxTime )


yScale : { width : Float, height : Float } -> List Lap -> ContinuousScale Float
yScale size laps =
    let
        ( minTime, maxTime ) =
            laps
                |> filterOutlierLaps
                |> List.map .time
                |> (\ts ->
                        ( List.minimum ts |> Maybe.withDefault 0 |> toFloat
                        , List.maximum ts |> Maybe.withDefault 0 |> toFloat
                        )
                   )

        padding_y =
            (maxTime - minTime) * 0.1

        ( adjustedMin, adjustedMax ) =
            ( minTime - padding_y
            , maxTime + padding_y
            )
    in
    Scale.linear ( size.height - paddingBottom, padding ) ( adjustedMin, adjustedMax )



-- Axes


xGridLines : { width : Float, height : Float } -> List Lap -> Svg msg
xGridLines size laps =
    let
        gridIntervalMs =
            15 * 60 * 1000

        elapsedTimes =
            laps |> List.map .elapsed

        minElapsedMs =
            List.minimum elapsedTimes |> Maybe.withDefault 0

        maxElapsedMs =
            List.maximum elapsedTimes |> Maybe.withDefault 0

        gridTimes =
            List.range 0 (maxElapsedMs // gridIntervalMs + 1)
                |> List.map (\i -> i * gridIntervalMs)
                |> List.filter (\t -> t >= minElapsedMs && t <= maxElapsedMs)

        top =
            padding

        bottom =
            size.height - paddingBottom
    in
    g [] <|
        List.map
            (\t ->
                let
                    x =
                        toFloat t |> Scale.convert (xScale size laps)
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
            gridTimes


formatElapsedHoursMinutes : Int -> String
formatElapsedHoursMinutes ms =
    let
        h =
            ms // (60 * 60 * 1000)

        m =
            remainderBy (60 * 60 * 1000) ms // (60 * 1000)
    in
    String.fromInt h ++ ":" ++ String.padLeft 2 '0' (String.fromInt m)


xAxis : { width : Float, height : Float } -> List Lap -> Svg msg
xAxis size laps =
    let
        tickIntervalMs =
            5 * 60 * 1000

        elapsedTimes =
            laps |> List.map .elapsed

        minElapsedMs =
            List.minimum elapsedTimes |> Maybe.withDefault 0

        maxElapsedMs =
            List.maximum elapsedTimes |> Maybe.withDefault 0

        allTicks =
            List.range (minElapsedMs // tickIntervalMs) (maxElapsedMs // tickIntervalMs + 1)
                |> List.map (\i -> toFloat (i * tickIntervalMs))

        axis =
            fromUnstyled <|
                Axis.bottom
                    [ ticks allTicks
                    , tickSizeOuter 0
                    , tickSizeInner -3
                    , tickPadding 8
                    , tickFormat
                        (\f ->
                            if modBy (15 * 60 * 1000) (round f) == 0 then
                                formatElapsedHoursMinutes (round f)

                            else
                                ""
                        )
                    ]
                    (xScale size laps)
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
        , transform [ Translate 0 (size.height - paddingBottom) ]
        ]
        [ axis ]


yAxis : { width : Float, height : Float } -> List Lap -> Svg msg
yAxis size laps =
    let
        axis =
            fromUnstyled <|
                Axis.left
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 5
                    , tickFormat (round >> Duration.toString)
                    ]
                    (yScale size laps)
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
        , transform [ Translate paddingLeft 0 ]
        ]
        [ axis ]



-- Rendering


lapTimeProgressionChart : { width : Float, height : Float } -> List LapTimeSeries -> Html msg
lapTimeProgressionChart size series =
    let
        allLaps =
            series |> List.concatMap .laps
    in
    svg
        [ SvgAttr.width "100%"
        , viewBox 0 0 size.width size.height
        ]
        ([ xGridLines size allLaps
         , xAxis size allLaps
         , yAxis size allLaps
         ]
            ++ (series |> List.map (renderLapSeries size allLaps))
        )


renderLapSeries : { width : Float, height : Float } -> List Lap -> LapTimeSeries -> Svg msg
renderLapSeries size allLaps series =
    let
        dataPoints =
            series.laps
                |> List.map
                    (\{ time, elapsed } ->
                        ( elapsed
                            |> toFloat
                            |> Scale.convert (xScale size allLaps)
                        , time
                            |> toFloat
                            |> Scale.convert (yScale size allLaps)
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
