module Motorsport.Widget.CloseBattles exposing (view)

import Axis exposing (tickCount, tickFormat, tickSizeInner, tickSizeOuter)
import Color
import Css exposing (pct, px)
import Css.Extra
import Css.Global exposing (children, descendants, each)
import Html.Styled as Html exposing (Html, div, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import List.NonEmpty as NonEmpty exposing (NonEmpty)
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Lap exposing (Lap)
import Motorsport.RaceControl.ViewModel as ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget as Widget
import Path.Styled as Path
import Scale exposing (ContinuousScale)
import Shape
import Svg.Styled exposing (Svg, fromUnstyled, g, svg)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes as TSA
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Length(..), Opacity(..), Paint(..), Transform(..))


type alias CloseBattle =
    { cars : NonEmpty ViewModelItem
    , position : Int
    }


type alias CarProgressionData =
    { carNumber : String
    , laps : List Lap
    , color : Color.Color
    }


type alias CarGapData =
    { carNumber : String
    , gapData : List { lap : Int, gap : Int }
    , color : Color.Color
    }


w : Float
w =
    320


h : Float
h =
    140


padding : Float
padding =
    5


paddingLeft : Float
paddingLeft =
    padding + 45


paddingBottom : Float
paddingBottom =
    padding + 15


view : ViewModel -> Html msg
view viewModel =
    let
        closeBattles =
            if viewModel.leadLapNumber > 1 then
                detectCloseBattles viewModel

            else
                []
    in
    Widget.container "Battles" <|
        if List.isEmpty closeBattles then
            Widget.emptyState "No close battles detected"

        else
            div [] (List.map closeBattleItem closeBattles)


detectCloseBattles : ViewModel -> List CloseBattle
detectCloseBattles viewModel =
    ViewModel.groupCarsByCloseIntervals viewModel
        |> List.filterMap createCloseBattle


createCloseBattle : List ViewModelItem -> Maybe CloseBattle
createCloseBattle cars =
    NonEmpty.fromList cars
        |> Maybe.map
            (\nonEmptyCars ->
                { cars = nonEmptyCars
                , position = NonEmpty.head nonEmptyCars |> .position
                }
            )


closeBattleItem : CloseBattle -> Html msg
closeBattleItem { cars } =
    div
        [ css
            [ Css.property "display" "grid"
            , Css.property "row-gap" "10px"
            , Css.padding2 (px 15) Css.zero
            , Css.fontSize (px 12)
            , Css.nthChild "n+2"
                [ Css.borderTop3 (px 1) Css.solid (Css.hsl 0 0 0.4) ]
            ]
        ]
        [ battleHeaderView cars
        , battleChart cars
        , lapTimeComparison cars
        ]


battleHeaderView : NonEmpty ViewModelItem -> Html msg
battleHeaderView cars =
    let
        carNumbers =
            cars
                |> NonEmpty.toList
                |> List.map (.metaData >> .carNumber)
                |> String.join " - "
    in
    div
        [ css
            [ Css.fontSize (px 14)
            , Css.fontWeight Css.bold
            , Css.color (Css.hsl 0 0 0.9)
            ]
        ]
        [ text carNumbers ]


lapTimeComparison : NonEmpty ViewModelItem -> Html msg
lapTimeComparison cars =
    let
        allRecentLaps =
            let
                options =
                    { leadLapNumber = ViewModel.getLeadLapNumber cars }
            in
            cars
                |> NonEmpty.map (\car -> ViewModel.getRecentLaps 3 options car.history)

        headerLaps =
            NonEmpty.head allRecentLaps
    in
    Html.table
        [ css
            [ Css.width (pct 100)
            , Css.borderCollapse Css.separate
            , Css.borderSpacing (px 2)
            , descendants
                [ Css.Global.th
                    [ Css.padding Css.zero
                    , Css.fontSize (px 10)
                    , Css.fontWeight Css.bold
                    , Css.textAlign Css.center
                    , Css.color (Css.hsl 0 0 0.7)
                    ]
                ]
            ]
        ]
        [ Html.thead []
            [ Html.tr []
                (Html.th [] []
                    :: Html.th [] [ text "Interval" ]
                    :: List.map (\lap -> Html.th [] [ text ("Lap " ++ String.fromInt lap.lap) ]) headerLaps
                )
            ]
        , Html.tbody []
            (NonEmpty.map2 (\car recentLaps -> carTimeRow car recentLaps allRecentLaps) cars allRecentLaps
                |> NonEmpty.toList
            )
        ]


carTimeRow : ViewModelItem -> List Lap -> NonEmpty (List Lap) -> Html msg
carTimeRow car carLaps allCarsLaps =
    let
        leaderLaps =
            NonEmpty.head allCarsLaps

        lapCells =
            List.map2
                (\leaderLap lap ->
                    let
                        allTimesForThisLap =
                            allCarsLaps
                                |> NonEmpty.toList
                                |> List.filterMap (List.Extra.find (\otherLap -> otherLap.lap == lap.lap))
                                |> List.map .time

                        isFastest =
                            allTimesForThisLap
                                |> List.minimum
                                |> Maybe.map (\fastest -> lap.time == fastest)
                                |> Maybe.withDefault False
                    in
                    Html.td [] [ lapTimeCell { isFastest = isFastest, groupLeader = leaderLap } lap ]
                )
                leaderLaps
                carLaps

        intervalCell =
            Html.td []
                [ div
                    [ css
                        [ Css.padding (px 4)
                        , Css.borderRadius (px 4)
                        , Css.textAlign Css.center
                        , Css.fontSize (px 10)
                        , Css.fontWeight Css.bold
                        , Css.letterSpacing (px 0.3)
                        , Css.backgroundColor (Css.hsl 0 0 0.25)
                        , Css.color (Css.hsl 0 0 1)
                        ]
                    ]
                    [ text (Gap.toString car.timing.interval) ]
                ]
    in
    Html.tr [ css [ children [ Css.Global.td [ Css.padding Css.zero ] ] ] ]
        (Html.th [ css [ Css.width (px 25) ] ] [ text car.metaData.carNumber ]
            :: intervalCell
            :: lapCells
        )


lapTimeCell : { isFastest : Bool, groupLeader : Lap } -> Lap -> Html msg
lapTimeCell { isFastest, groupLeader } lap =
    let
        cellBackgroundColor =
            if isFastest then
                Css.hsl 120 0.7 0.4

            else
                Css.hsl 0 0 0.4

        difference =
            lap.time - groupLeader.time

        displayText =
            if difference == 0 then
                Duration.toString lap.time

            else if difference > 0 then
                "+" ++ Duration.toString difference

            else
                "-" ++ Duration.toString (abs difference)
    in
    div
        [ css
            [ Css.padding (px 4)
            , Css.borderRadius (px 4)
            , Css.textAlign Css.center
            , Css.fontSize (px 10)
            , Css.fontWeight Css.bold
            , Css.letterSpacing (px 0.3)
            , Css.backgroundColor cellBackgroundColor
            , Css.color (Css.hsl 0 0 1)
            ]
        ]
        [ text displayText ]


battleChart : NonEmpty ViewModelItem -> Html msg
battleChart cars =
    let
        options =
            { leadLapNumber = ViewModel.getLeadLapNumber cars }

        carProgressionData =
            cars
                |> NonEmpty.map
                    (\car ->
                        { carNumber = car.metaData.carNumber
                        , laps = ViewModel.getRecentLaps 10 options car.history
                        , color = generateCarColor car.metaData.carNumber
                        }
                    )

        carGapData =
            calculateGapData carProgressionData

        allGapPoints =
            carGapData
                |> NonEmpty.toList
                |> List.concatMap .gapData
    in
    svg
        [ InPx.width w
        , InPx.height h
        , TSA.viewBox 0 0 w h
        ]
        ([ xAxis allGapPoints
         , yAxis allGapPoints
         ]
            ++ (carGapData |> NonEmpty.toList |> renderBattleGapLines)
        )


calculateGapData : NonEmpty CarProgressionData -> NonEmpty CarGapData
calculateGapData carProgressionData =
    let
        allLaps =
            carProgressionData
                |> NonEmpty.toList
                |> List.concatMap .laps

        fastestLapTime =
            allLaps
                |> List.Extra.minimumBy .time
                |> Maybe.map .time
                |> Maybe.withDefault 0

        fastestPlusSevenPercent =
            (toFloat fastestLapTime * 1.07) |> round

        averageLapTime =
            allLaps
                |> List.filter (\lap -> lap.time < fastestPlusSevenPercent)
                |> List.map (.time >> toFloat)
                |> average
                |> Maybe.withDefault 0
                |> round

        calculateAverageElapsedForLap lapNumber =
            let
                maxLapNumber =
                    allLaps
                        |> List.Extra.maximumBy .lap
                        |> Maybe.map .lap
                        |> Maybe.withDefault 1

                latestLeaderElapsed =
                    carProgressionData
                        |> NonEmpty.head
                        |> .laps
                        |> List.Extra.maximumBy .lap
                        |> Maybe.map .elapsed
                        |> Maybe.withDefault 0
            in
            latestLeaderElapsed - (averageLapTime * (maxLapNumber - lapNumber))

        calculateGapForCar car =
            let
                gapData =
                    car.laps
                        |> List.map
                            (\lap ->
                                let
                                    averageElapsedAtThisLap =
                                        calculateAverageElapsedForLap lap.lap

                                    gap =
                                        lap.elapsed - averageElapsedAtThisLap
                                in
                                { lap = lap.lap, gap = gap }
                            )
            in
            { carNumber = car.carNumber
            , gapData = gapData
            , color = car.color
            }
    in
    carProgressionData
        |> NonEmpty.map calculateGapForCar


average : List Float -> Maybe Float
average values =
    case values of
        [] ->
            Nothing

        _ ->
            Just (List.sum values / toFloat (List.length values))


xScale : List { lap : Int, gap : Int } -> ContinuousScale Float
xScale gapPoints =
    let
        ( minLap, maxLap ) =
            gapPoints
                |> List.map .lap
                |> (\laps ->
                        ( List.minimum laps |> Maybe.withDefault 1
                        , List.maximum laps |> Maybe.withDefault 1
                        )
                   )
    in
    Scale.linear ( paddingLeft, w - padding ) ( toFloat minLap, toFloat maxLap )


yScale : List { lap : Int, gap : Int } -> ContinuousScale Float
yScale gapPoints =
    let
        ( minGap, maxGap ) =
            gapPoints
                |> List.filter (\{ gap } -> -50000 <= gap && gap <= 50000)
                |> List.map .gap
                |> (\gaps ->
                        ( List.minimum gaps |> Maybe.withDefault 0 |> toFloat
                        , List.maximum gaps |> Maybe.withDefault 0 |> toFloat
                        )
                   )

        padding_y =
            max 1000.0 ((maxGap - minGap) * 0.1)

        ( adjustedMin, adjustedMax ) =
            ( minGap - padding_y
            , maxGap + padding_y
            )
    in
    Scale.linear ( h - paddingBottom, padding ) ( adjustedMax, adjustedMin )


xAxis : List { lap : Int, gap : Int } -> Svg msg
xAxis gapPoints =
    let
        axis =
            fromUnstyled <|
                Axis.bottom
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 3
                    , tickFormat (Basics.round >> String.fromInt)
                    ]
                    (xScale gapPoints)
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
        , TSA.transform [ Translate 0 (h - paddingBottom) ]
        ]
        [ axis ]


yAxis : List { lap : Int, gap : Int } -> Svg msg
yAxis gapPoints =
    let
        axis =
            fromUnstyled <|
                Axis.left
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 5
                    , tickFormat (Basics.round >> Duration.toString)
                    ]
                    (yScale gapPoints)
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
        , TSA.transform [ Translate paddingLeft 0 ]
        ]
        [ axis ]


renderBattleGapLines : List CarGapData -> List (Svg msg)
renderBattleGapLines carGapData =
    let
        allGapPoints =
            List.concatMap .gapData carGapData
    in
    carGapData
        |> List.concatMap (renderCarGapLine allGapPoints)


renderCarGapLine : List { lap : Int, gap : Int } -> CarGapData -> List (Svg msg)
renderCarGapLine allGapPoints carData =
    let
        dataPoints =
            carData.gapData
                |> List.map
                    (\{ lap, gap } ->
                        ( lap
                            |> toFloat
                            |> Scale.convert (xScale allGapPoints)
                        , gap
                            |> toFloat
                            |> Scale.convert (yScale allGapPoints)
                        )
                    )

        linePath =
            dataPoints
                |> List.map Just
                |> Shape.line Shape.linearCurve

        points =
            List.map point dataPoints

        point ( x, y ) =
            Svg.Styled.circle
                [ InPx.cx x
                , InPx.cy y
                , InPx.r 2
                , SvgAttr.css
                    [ Css.fill (colorToCss carData.color)
                    , Css.property "stroke" "none"
                    , Css.opacity (Css.num 0.7)
                    ]
                ]
                []
    in
    Path.element linePath
        [ SvgAttr.stroke (Color.toCssString carData.color)
        , SvgAttr.strokeWidth "1.5"
        , SvgAttr.fill "none"
        , SvgAttr.strokeOpacity "0.5"
        ]
        :: points


generateCarColor : String -> Color.Color
generateCarColor carNumber =
    let
        carHash =
            String.toInt carNumber |> Maybe.withDefault 0

        ( hue, saturation, lightness ) =
            ( carHash * 37 |> modBy 360 |> toFloat
            , 0.7 + (toFloat (carHash * 17 |> modBy 30) / 100)
            , 0.5 + (toFloat (carHash * 13 |> modBy 20) / 100)
            )
    in
    Color.hsl (hue / 360) saturation lightness


colorToCss : Color.Color -> Css.Color
colorToCss color =
    let
        rgba =
            Color.toRgba color
    in
    Css.rgba (Basics.round (rgba.red * 255)) (Basics.round (rgba.green * 255)) (Basics.round (rgba.blue * 255)) rgba.alpha
