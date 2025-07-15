module Motorsport.Widget.CloseBattles exposing (view)

import Css exposing (..)
import Css.Global exposing (children, descendants)
import Html.Styled as Html exposing (Html, div, h3, text)
import Html.Styled.Attributes exposing (css)
import List.Extra
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap
import Motorsport.Lap exposing (Lap)
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)


type alias CloseBattle =
    { leader : ViewModelItem
    , follower : ViewModelItem
    , interval : Duration
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
    div
        [ css
            [ height (pct 100)
            , overflowY hidden
            , padding (px 10)
            , borderRadius (px 12)
            , property "display" "grid"
            , property "grid-template-rows" "auto 1fr"
            , property "row-gap" "10px"
            , backgroundColor (hsl 0 0 0.2)
            ]
        ]
        [ h3
            [ css
                [ margin zero
                , fontSize (rem 1.1)
                , fontWeight bold
                , letterSpacing (px 0.5)
                , color (hsl 0 0 0.9)
                ]
            ]
            [ text "Battles" ]
        , contentView closeBattlePairs
        ]


detectCloseBattles : ViewModel -> List CloseBattle
detectCloseBattles viewModel =
    viewModel
        |> List.indexedMap (detectBattleForCar viewModel)
        |> List.filterMap identity
        |> List.sortBy .position


detectBattleForCar : ViewModel -> Int -> ViewModelItem -> Maybe CloseBattle
detectBattleForCar viewModel index car =
    case car.timing.interval of
        Gap.Seconds duration ->
            if duration <= 1500 then
                List.Extra.getAt (index - 1) viewModel
                    |> Maybe.map
                        (\leader ->
                            { leader = leader
                            , follower = car
                            , interval = duration
                            , position = car.position
                            }
                        )

            else
                Nothing

        _ ->
            Nothing


contentView : List CloseBattle -> Html msg
contentView closeBattlePairs =
    div [ css [ height (pct 100) ] ]
        (if List.isEmpty closeBattlePairs then
            [ div
                [ css
                    [ fontStyle italic
                    , color (hsl 0 0 0.7)
                    , textAlign center
                    , padding (px 20)
                    , backgroundColor (hsl 0 0 0.1)
                    , borderRadius (px 8)
                    , border3 (px 1) solid (hsl 0 0 0.25)
                    ]
                ]
                [ text "No close battles detected" ]
            ]

         else
            List.map closeBattleItem closeBattlePairs
        )


closeBattleItem : CloseBattle -> Html msg
closeBattleItem { leader, follower, interval } =
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
        [ battleHeaderView leader follower interval
        , lapTimeComparison leader follower
        ]


battleHeaderView : ViewModelItem -> ViewModelItem -> Duration -> Html msg
battleHeaderView a b interval =
    div
        [ css
            [ displayFlex
            , justifyContent spaceBetween
            , alignItems center
            ]
        ]
        [ div [ css [ fontSize (px 14), fontWeight bold, color (hsl 0 0 0.9) ] ]
            [ text ("#" ++ a.metaData.carNumber ++ " vs #" ++ b.metaData.carNumber) ]
        , div [ css [ fontSize (px 12), fontWeight bold ] ]
            [ text ("+" ++ Duration.toString interval) ]
        ]


lapTimeComparison : ViewModelItem -> ViewModelItem -> Html msg
lapTimeComparison carA carB =
    let
        recentLapsPair =
            List.Extra.zip carA.history carB.history
                |> List.reverse
                |> List.take 4
                |> List.reverse
                |> List.unzip

        ( lapsA, lapsB ) =
            recentLapsPair
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
                    :: List.map (\lap -> Html.th [] [ text ("Lap " ++ String.fromInt lap.lap) ]) lapsA
                )
            ]
        , Html.tbody []
            [ carTimeRow carA.metaData.carNumber lapsA lapsB False
            , carTimeRow carB.metaData.carNumber lapsB lapsA True
            ]
        ]


carTimeRow : String -> List Lap -> List Lap -> Bool -> Html msg
carTimeRow carNumber carA carB showDifference =
    Html.tr [ css [ children [ Css.Global.td [ padding zero ] ] ] ]
        (Html.th [ css [ width (px 40) ] ] [ text ("#" ++ carNumber) ]
            :: List.map2 (\lapA lapB -> Html.td [] [ lapTimeCell showDifference lapA lapB ]) carA carB
        )


lapTimeCell : Bool -> Lap -> Lap -> Html msg
lapTimeCell showDifference lapA lapB =
    let
        cellBackgroundColor =
            if lapA.time < lapB.time then
                hsl 120 0.7 0.4

            else
                hsl 0 0 0.4

        displayText =
            if showDifference then
                let
                    difference =
                        lapA.time - lapB.time
                in
                if difference >= 0 then
                    "+" ++ Duration.toString difference

                else
                    "-" ++ Duration.toString (abs difference)

            else
                Duration.toString lapA.time
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
