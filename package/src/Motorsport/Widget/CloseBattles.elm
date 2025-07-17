module Motorsport.Widget.CloseBattles exposing
    ( view
    , groupConsecutiveCloseCars
    )

{-|

@docs view
@docs groupConsecutiveCloseCars

-}

import Axis exposing (tickCount, tickFormat, tickSizeInner, tickSizeOuter)
import Color
import Css exposing (pct, px)
import Css.Extra
import Css.Global exposing (children, descendants, each)
import Html.Styled as Html exposing (Html, div, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap
import Motorsport.Lap exposing (Lap)
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
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
    { cars : List ViewModelItem
    , position : Int
    }


type alias CarProgressionData =
    { carNumber : String
    , laps : List Lap
    , color : Color.Color
    }


type alias CarGapData =
    { carNumber : String
    , gapData : List { elapsed : Int, gap : Int }
    , color : Color.Color
    }


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


view : Clock.Model -> ViewModel -> Html msg
view clock viewModel =
    let
        currentLapNumber =
            viewModel |> List.head |> Maybe.map .lap |> Maybe.withDefault 0

        closeBattles =
            if currentLapNumber > 1 then
                detectCloseBattles viewModel

            else
                []
    in
    Widget.container "Battles" (contentView clock closeBattles)


detectCloseBattles : ViewModel -> List CloseBattle
detectCloseBattles viewModel =
    groupConsecutiveCloseCars viewModel
        |> List.map createCloseBattle


groupConsecutiveCloseCars : ViewModel -> List (List ViewModelItem)
groupConsecutiveCloseCars viewModel =
    let
        isCloseToNext current =
            case current.timing.interval of
                Gap.Seconds duration ->
                    duration <= 1500

                _ ->
                    False

        groupCars cars =
            case cars of
                [] ->
                    []

                first :: rest ->
                    let
                        ( group, remaining ) =
                            List.Extra.span isCloseToNext rest
                    in
                    (first :: group) :: groupCars remaining
    in
    viewModel
        |> groupCars
        |> List.filter (\group -> List.length group >= 2)


createCloseBattle : List ViewModelItem -> CloseBattle
createCloseBattle cars =
    { cars = cars
    , position =
        List.head cars
            |> Maybe.map .position
            |> Maybe.withDefault 1
    }


contentView : Clock.Model -> List CloseBattle -> Html msg
contentView clock closeBattles =
    div [ css [ Css.height (pct 100) ] ]
        (if List.isEmpty closeBattles then
            [ Widget.emptyState "No close battles detected" ]

         else
            List.map (closeBattleItem clock) closeBattles
        )


closeBattleItem : Clock.Model -> CloseBattle -> Html msg
closeBattleItem clock { cars } =
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
        , battleChart clock cars
        , lapTimeComparison cars
        ]


battleHeaderView : List ViewModelItem -> Html msg
battleHeaderView cars =
    let
        carNumbers =
            cars
                |> List.map (.metaData >> .carNumber)
                |> String.join " - "
    in
    div
        [ css
            [ Css.displayFlex
            , Css.justifyContent Css.spaceBetween
            , Css.alignItems Css.center
            ]
        ]
        [ div
            [ css
                [ Css.fontSize (px 14)
                , Css.fontWeight Css.bold
                , Css.color (Css.hsl 0 0 0.9)
                ]
            ]
            [ text carNumbers ]
        ]


lapTimeComparison : List ViewModelItem -> Html msg
lapTimeComparison cars =
    let
        allRecentLaps =
            let
                leaderLapNumbers =
                    cars
                        |> List.head
                        |> Maybe.map (.history >> List.reverse >> List.take 3 >> List.reverse >> List.map .lap)
                        |> Maybe.withDefault []
            in
            cars
                |> List.map
                    (\car ->
                        car.history
                            |> List.filterMap
                                (\lap ->
                                    if List.member lap.lap leaderLapNumbers then
                                        Just lap

                                    else
                                        Nothing
                                )
                    )

        headerLaps =
            List.head allRecentLaps |> Maybe.withDefault []
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
            (List.map2 (\car recentLaps -> carTimeRow car recentLaps allRecentLaps) cars allRecentLaps)
        ]


carTimeRow : ViewModelItem -> List Lap -> List (List Lap) -> Html msg
carTimeRow car carLaps allCarsLaps =
    let
        lapCells =
            List.indexedMap
                (\lapIndex lap ->
                    let
                        allTimesForThisLap =
                            allCarsLaps
                                |> List.filterMap (List.Extra.getAt lapIndex)
                                |> List.map .time

                        groupLeaderTime =
                            allCarsLaps
                                |> List.head
                                |> Maybe.andThen (List.Extra.getAt lapIndex)
                                |> Maybe.map .time

                        isFastest =
                            allTimesForThisLap
                                |> List.minimum
                                |> Maybe.map (\fastest -> lap.time == fastest)
                                |> Maybe.withDefault False
                    in
                    Html.td [] [ lapTimeCell lap isFastest groupLeaderTime ]
                )
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


lapTimeCell : Lap -> Bool -> Maybe Duration -> Html msg
lapTimeCell lap isFastest groupLeaderTime =
    let
        cellBackgroundColor =
            if isFastest then
                Css.hsl 120 0.7 0.4

            else
                Css.hsl 0 0 0.4

        displayText =
            case groupLeaderTime of
                Just leaderTime ->
                    let
                        difference =
                            lap.time - leaderTime
                    in
                    if difference == 0 then
                        Duration.toString lap.time

                    else if difference > 0 then
                        "+" ++ Duration.toString difference

                    else
                        "-" ++ Duration.toString (abs difference)

                Nothing ->
                    Duration.toString lap.time
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


battleChart : Clock.Model -> List ViewModelItem -> Html msg
battleChart clock cars =
    let
        carProgressionData =
            cars
                |> List.map
                    (\car ->
                        let
                            allLaps_ =
                                extractLapDataForCar clock car.history
                        in
                        { carNumber = car.metaData.carNumber
                        , laps = allLaps_
                        , color = generateCarColor car.metaData.carNumber
                        }
                    )
                |> List.filter (\car -> List.length car.laps >= 2)

        carGapData =
            calculateGapData carProgressionData

        allGapPoints =
            List.concatMap .gapData carGapData
    in
    if List.isEmpty carGapData then
        div [] []

    else
        svg
            [ InPx.width w
            , InPx.height h
            , TSA.viewBox 0 0 w h
            , css [ Css.marginBottom (px 10) ]
            ]
            ([ xAxis allGapPoints
             , yAxis allGapPoints
             ]
                ++ renderBattleGapLines carGapData
            )


calculateGapData : List CarProgressionData -> List CarGapData
calculateGapData carProgressionData =
    let
        leaderData =
            carProgressionData
                |> List.head
                |> Maybe.map .laps
                |> Maybe.withDefault []

        calculateGapForCar car =
            let
                gapData =
                    car.laps
                        |> List.map
                            (\lap ->
                                let
                                    leaderLapAtSameTime =
                                        leaderData
                                            |> List.Extra.find (\leaderLap -> leaderLap.lap == lap.lap)
                                            |> Maybe.map .elapsed
                                            |> Maybe.withDefault lap.elapsed

                                    gap =
                                        lap.elapsed - leaderLapAtSameTime
                                in
                                { elapsed = lap.elapsed, gap = gap }
                            )
            in
            { carNumber = car.carNumber
            , gapData = gapData
            , color = car.color
            }
    in
    carProgressionData
        |> List.map calculateGapForCar


xScale : List { elapsed : Int, gap : Int } -> ContinuousScale Float
xScale gapPoints =
    let
        ( minTime, maxTime ) =
            gapPoints
                |> List.map .elapsed
                |> (\ts ->
                        ( List.minimum ts |> Maybe.withDefault 0
                        , List.maximum ts |> Maybe.withDefault 0
                        )
                   )
    in
    Scale.linear ( paddingLeft, w - padding ) ( toFloat minTime, toFloat maxTime )


yScale : List { elapsed : Int, gap : Int } -> ContinuousScale Float
yScale gapPoints =
    let
        ( minGap, maxGap ) =
            gapPoints
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


xAxis : List { elapsed : Int, gap : Int } -> Svg msg
xAxis gapPoints =
    let
        axis =
            fromUnstyled <|
                Axis.bottom
                    [ tickCount 4
                    , tickSizeOuter 0
                    , tickSizeInner 3
                    , tickFormat (Basics.round >> Duration.toString)
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


yAxis : List { elapsed : Int, gap : Int } -> Svg msg
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


renderCarGapLine : List { elapsed : Int, gap : Int } -> CarGapData -> List (Svg msg)
renderCarGapLine allGapPoints carData =
    let
        dataPoints =
            carData.gapData
                |> List.map
                    (\{ elapsed, gap } ->
                        ( elapsed
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
