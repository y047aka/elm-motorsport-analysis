module Motorsport.Widget.CloseBattles exposing (view)

import Css exposing (..)
import Css.Global exposing (children, descendants)
import Html.Styled as Html exposing (Html, div, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap
import Motorsport.Lap exposing (Lap)
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget as Widget


type alias CloseBattle =
    { cars : List ViewModelItem
    , position : Int
    }


view : ViewModel -> Html msg
view viewModel =
    let
        currentLapNumber =
            viewModel |> List.head |> Maybe.map .lap |> Maybe.withDefault 0

        closeBattlePairs =
            if currentLapNumber > 2 then
                detectCloseBattles viewModel

            else
                []
    in
    Widget.container "Battles" (contentView closeBattlePairs)


detectCloseBattles : ViewModel -> List CloseBattle
detectCloseBattles viewModel =
    groupConsecutiveCloseCars viewModel
        |> List.filter (\group -> List.length group >= 2)
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
                            takeWhileClose first rest []
                    in
                    (first :: group) :: groupCars remaining

        takeWhileClose _ remaining acc =
            case remaining of
                [] ->
                    ( List.reverse acc, [] )

                next :: rest ->
                    if isCloseToNext next then
                        takeWhileClose next rest (next :: acc)

                    else
                        ( List.reverse acc, remaining )
    in
    groupCars viewModel


createCloseBattle : List ViewModelItem -> CloseBattle
createCloseBattle cars =
    let
        firstCar =
            List.head cars

        position =
            firstCar |> Maybe.map .position |> Maybe.withDefault 1
    in
    { cars = cars
    , position = position
    }


contentView : List CloseBattle -> Html msg
contentView closeBattlePairs =
    div [ css [ height (pct 100) ] ]
        (if List.isEmpty closeBattlePairs then
            [ Widget.emptyState "No close battles detected" ]

         else
            List.map closeBattleItem closeBattlePairs
        )


closeBattleItem : CloseBattle -> Html msg
closeBattleItem { cars } =
    div
        [ css
            [ property "display" "grid"
            , property "row-gap" "10px"
            , padding2 (px 15) zero
            , fontSize (px 12)
            , nthChild "n+2"
                [ borderTop3 (px 1) solid (hsl 0 0 0.4) ]
            ]
        ]
        [ battleHeaderView cars
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
            [ displayFlex
            , justifyContent spaceBetween
            , alignItems center
            ]
        ]
        [ div [ css [ fontSize (px 14), fontWeight bold, color (hsl 0 0 0.9) ] ]
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
            [ width (pct 100)
            , borderCollapse separate
            , borderSpacing (px 2)
            , descendants
                [ Css.Global.th
                    [ padding zero
                    , fontSize (px 10)
                    , fontWeight bold
                    , textAlign center
                    , color (hsl 0 0 0.7)
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
                        [ padding (px 4)
                        , borderRadius (px 4)
                        , textAlign center
                        , fontSize (px 10)
                        , fontWeight bold
                        , letterSpacing (px 0.3)
                        , backgroundColor (hsl 0 0 0.25)
                        , color (hsl 0 0 1)
                        ]
                    ]
                    [ text (Gap.toString car.timing.interval) ]
                ]
    in
    Html.tr [ css [ children [ Css.Global.td [ padding zero ] ] ] ]
        (Html.th [ css [ width (px 25) ] ] [ text car.metaData.carNumber ]
            :: intervalCell
            :: lapCells
        )


lapTimeCell : Lap -> Bool -> Maybe Duration -> Html msg
lapTimeCell lap isFastest groupLeaderTime =
    let
        cellBackgroundColor =
            if isFastest then
                hsl 120 0.7 0.4

            else
                hsl 0 0 0.4

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
            [ padding (px 4)
            , borderRadius (px 4)
            , textAlign center
            , fontSize (px 10)
            , fontWeight bold
            , letterSpacing (px 0.3)
            , backgroundColor cellBackgroundColor
            , color (hsl 0 0 1)
            ]
        ]
        [ text displayText ]
