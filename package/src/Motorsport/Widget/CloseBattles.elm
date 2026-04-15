module Motorsport.Widget.CloseBattles exposing (closeBattleItem, view)

import Axis exposing (tickCount, tickFormat, tickPadding, tickSizeInner, tickSizeOuter, ticks)
import Css exposing (Color, pct, px)
import Css.Extra
import Css.Global exposing (children, descendants, each)
import Html.Styled as Html exposing (Html, div, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import List.NonEmpty as NonEmpty exposing (NonEmpty)
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
import Motorsport.Widget as Widget
import Path.Styled as Path
import Scale exposing (ContinuousScale)
import Shape
import Svg.Styled exposing (Svg, fromUnstyled, g, line, svg)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes as TSA
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Transform(..))


type alias CloseBattle =
    { cars : NonEmpty StandingsEntry
    , position : Int
    }


type alias CarProgressionData =
    { carNumber : String
    , laps : List Lap
    , color : Color
    }


type alias CarGapData =
    { carNumber : String
    , gapData : List { lap : Int, gap : Int }
    , color : Color
    }


padding : Float
padding =
    5


paddingLeft : Float
paddingLeft =
    padding + 60


paddingBottom : Float
paddingBottom =
    padding + 15


view : { width : Float, height : Float } -> Standings -> Html msg
view size standings =
    let
        closeBattles =
            if standings.laps > 1 then
                detectCloseBattles standings

            else
                []
    in
    Widget.container "Battles" <|
        if List.isEmpty closeBattles then
            Widget.emptyState "No close battles detected"

        else
            div [] (List.map (closeBattleItem size) closeBattles)


detectCloseBattles : Standings -> List CloseBattle
detectCloseBattles standings =
    Standings.groupCarsByCloseIntervals standings
        |> List.filterMap createCloseBattle


createCloseBattle : List StandingsEntry -> Maybe CloseBattle
createCloseBattle cars =
    NonEmpty.fromList cars
        |> Maybe.map
            (\nonEmptyCars ->
                { cars = nonEmptyCars
                , position = NonEmpty.head nonEmptyCars |> .position
                }
            )


closeBattleItem : { width : Float, height : Float } -> CloseBattle -> Html msg
closeBattleItem size { cars } =
    div
        [ css
            [ Css.property "display" "grid"
            , Css.property "row-gap" "10px"
            , Css.fontSize (px 12)
            ]
        ]
        [ battleChart size cars
        , lapTimeComparison cars
        ]


lapTimeComparison : NonEmpty StandingsEntry -> Html msg
lapTimeComparison cars =
    let
        allRecentLaps =
            let
                options =
                    { laps = NonEmpty.head cars |> .lapsCompleted }
            in
            cars
                |> NonEmpty.map (\car -> Standings.getRecentLaps 9 options car.history)

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


carTimeRow : StandingsEntry -> List Lap -> NonEmpty (List Lap) -> Html msg
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
                    [ text (Gap.toString car.intervalToAhead) ]
                ]
    in
    Html.tr [ css [ children [ Css.Global.td [ Css.padding Css.zero ] ] ] ]
        (Html.th [ css [ Css.width (px 25) ] ] [ text car.metadata.carNumber ]
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


battleChart : { width : Float, height : Float } -> NonEmpty StandingsEntry -> Html msg
battleChart size cars =
    let
        options =
            { laps = NonEmpty.head cars |> .lapsCompleted }

        carProgressionData =
            cars
                |> NonEmpty.map
                    (\car ->
                        { carNumber = car.metadata.carNumber
                        , laps = Standings.getRecentLaps 20 options car.history
                        , color = Manufacturer.toColorWithFallback car.metadata
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
        [ SvgAttr.width "100%"
        , TSA.viewBox 0 0 size.width size.height
        ]
        ([ xGridLines size allGapPoints
         , zeroLine size allGapPoints
         , xAxis size allGapPoints
         , yAxis size allGapPoints
         ]
            ++ (carGapData |> NonEmpty.toList |> renderBattleGapLines size)
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


xScale : { width : Float, height : Float } -> List { lap : Int, gap : Int } -> ContinuousScale Float
xScale size gapPoints =
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
    Scale.linear ( paddingLeft, size.width - padding ) ( toFloat minLap, toFloat maxLap )


yScale : { width : Float, height : Float } -> List { lap : Int, gap : Int } -> ContinuousScale Float
yScale size gapPoints =
    let
        ( minGap, maxGap ) =
            gapPoints
                |> List.filter (\{ gap } -> -60000 <= gap && gap <= 60000)
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
    Scale.linear ( size.height - paddingBottom, padding ) ( adjustedMax, adjustedMin )


xGridLines : { width : Float, height : Float } -> List { lap : Int, gap : Int } -> Svg msg
xGridLines size gapPoints =
    let
        lapNumbers =
            gapPoints |> List.map .lap

        minLap =
            List.minimum lapNumbers |> Maybe.withDefault 1

        maxLap =
            List.maximum lapNumbers |> Maybe.withDefault 1

        gridLaps =
            List.range minLap maxLap |> List.filter (\l -> modBy 5 l == 0)

        top =
            padding

        bottom =
            size.height - paddingBottom
    in
    g [] <|
        List.map
            (\lap ->
                let
                    x =
                        toFloat lap |> Scale.convert (xScale size gapPoints)
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


zeroLine : { width : Float, height : Float } -> List { lap : Int, gap : Int } -> Svg msg
zeroLine size gapPoints =
    let
        y =
            Scale.convert (yScale size gapPoints) 0
    in
    line
        [ SvgAttr.x1 (String.fromFloat paddingLeft)
        , SvgAttr.x2 (String.fromFloat (size.width - padding))
        , SvgAttr.y1 (String.fromFloat y)
        , SvgAttr.y2 (String.fromFloat y)
        , SvgAttr.css
            [ Css.property "stroke" "#555"
            , Css.Extra.strokeWidth 1
            ]
        ]
        []


xAxis : { width : Float, height : Float } -> List { lap : Int, gap : Int } -> Svg msg
xAxis size gapPoints =
    let
        lapNumbers =
            gapPoints |> List.map .lap

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
                    (xScale size gapPoints)
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
        , TSA.transform [ Translate 0 (size.height - paddingBottom) ]
        ]
        [ axis ]


yAxis : { width : Float, height : Float } -> List { lap : Int, gap : Int } -> Svg msg
yAxis size gapPoints =
    let
        axis =
            fromUnstyled <|
                Axis.left
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 5
                    , tickFormat (Basics.round >> Duration.toString)
                    ]
                    (yScale size gapPoints)
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
        , TSA.transform [ Translate paddingLeft 0 ]
        ]
        [ axis ]


renderBattleGapLines : { width : Float, height : Float } -> List CarGapData -> List (Svg msg)
renderBattleGapLines size carGapData =
    let
        allGapPoints =
            List.concatMap .gapData carGapData
    in
    carGapData
        |> List.concatMap (renderCarGapLine size allGapPoints)


renderCarGapLine : { width : Float, height : Float } -> List { lap : Int, gap : Int } -> CarGapData -> List (Svg msg)
renderCarGapLine size allGapPoints carData =
    let
        dataPoints =
            carData.gapData
                |> List.map
                    (\{ lap, gap } ->
                        ( lap
                            |> toFloat
                            |> Scale.convert (xScale size allGapPoints)
                        , gap
                            |> toFloat
                            |> Scale.convert (yScale size allGapPoints)
                        )
                    )

        linePath =
            dataPoints
                |> List.map Just
                |> Shape.line Shape.linearCurve

        lastPointElement =
            dataPoints
                |> List.Extra.last
                |> Maybe.map
                    (\( x, y ) ->
                        Svg.Styled.circle
                            [ InPx.cx x
                            , InPx.cy y
                            , InPx.r 3.0
                            , SvgAttr.css [ Css.fill carData.color ]
                            ]
                            []
                    )
                |> Maybe.withDefault (g [] [])
    in
    [ Path.element linePath
        [ SvgAttr.stroke carData.color.value
        , SvgAttr.strokeWidth "2"
        , SvgAttr.fill "none"
        ]
    , lastPointElement
    ]
