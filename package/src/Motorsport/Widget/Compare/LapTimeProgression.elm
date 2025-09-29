module Motorsport.Widget.Compare.LapTimeProgression exposing (view)

import Axis exposing (tickCount, tickFormat, tickSizeInner, tickSizeOuter)
import Css exposing (Color, num)
import Css.Extra
import Css.Global exposing (descendants, each)
import Html.Styled as Html exposing (Html, div, text)
import Html.Styled.Attributes exposing (class, css)
import List.Extra
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration
import Motorsport.Lap exposing (Lap)
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



-- Chart configuration


w : Float
w =
    320


h : Float
h =
    180


padding : Float
padding =
    15


paddingLeft : Float
paddingLeft =
    padding + 35


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


view : Clock.Model -> ViewModel -> Maybe ViewModelItem -> Maybe ViewModelItem -> Html msg
view clock viewModel carA carB =
    let
        body =
            case buildClassProgressionData clock viewModel carA carB of
                Err message ->
                    Widget.emptyState message

                Ok classData ->
                    lapTimeProgressionChart classData.series
    in
    div
        [ css
            [ Css.property "display" "grid"
            , Css.property "row-gap" "8px"
            , Css.property "padding-top" "12px"
            , Css.property "border-top" "1px solid hsl(0 0% 100% / 0.1)"
            ]
        ]
        [ Html.div [ class "text-sm font-semibold" ] [ text "Lap Time Progression" ]
        , body
        ]


buildClassProgressionData : Clock.Model -> ViewModel -> Maybe ViewModelItem -> Maybe ViewModelItem -> Result String ClassProgressionData
buildClassProgressionData clock viewModel carA carB =
    let
        carsInClass : List ViewModelItem
        carsInClass =
            viewModel.itemsByClass
                |> List.Extra.find (\( class_, _ ) -> Just class_ == Maybe.map (.metadata >> .class) carA)
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
                        , isSelected =
                            (Just carNumber == Maybe.map (.metadata >> .carNumber) carA)
                                || (Just carNumber == Maybe.map (.metadata >> .carNumber) carB)
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
            currentRaceTime - (60 * 60 * 1000)
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


xScale : List Lap -> ContinuousScale Float
xScale laps =
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
    Scale.linear ( paddingLeft, w - padding ) ( toFloat minTime, toFloat maxTime )


yScale : List Lap -> ContinuousScale Float
yScale laps =
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
    Scale.linear ( h - paddingBottom, padding ) ( adjustedMin, adjustedMax )



-- Axes


xAxis : List Lap -> Svg msg
xAxis laps =
    let
        axis =
            fromUnstyled <|
                Axis.bottom
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 3
                    , tickFormat (round >> Duration.toString)
                    ]
                    (xScale laps)
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
        , transform [ Translate 0 (h - paddingBottom) ]
        ]
        [ axis ]


yAxis : List Lap -> Svg msg
yAxis laps =
    let
        axis =
            fromUnstyled <|
                Axis.left
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 5
                    , tickFormat (round >> Duration.toString)
                    ]
                    (yScale laps)
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
        , transform [ Translate paddingLeft 0 ]
        ]
        [ axis ]



-- Rendering


lapTimeProgressionChart : List LapTimeSeries -> Html msg
lapTimeProgressionChart series =
    let
        allLaps =
            series |> List.concatMap .laps
    in
    svg
        [ InPx.width w
        , InPx.height h
        , viewBox 0 0 w h
        ]
        ([ xAxis allLaps
         , yAxis allLaps
         ]
            ++ (series |> List.map (renderLapSeries allLaps))
        )


renderLapSeries : List Lap -> LapTimeSeries -> Svg msg
renderLapSeries allLaps series =
    let
        dataPoints =
            series.laps
                |> List.map
                    (\{ time, elapsed } ->
                        ( elapsed
                            |> toFloat
                            |> Scale.convert (xScale allLaps)
                        , time
                            |> toFloat
                            |> Scale.convert (yScale allLaps)
                        )
                    )

        totalPoints =
            List.length dataPoints

        linePath =
            dataPoints
                |> List.map Just
                |> Shape.line Shape.linearCurve

        baseAttributes =
            [ SvgAttr.stroke series.color.value
            , SvgAttr.strokeWidth
                (if series.isSelected then
                    "1.5"

                 else
                    "1"
                )
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
