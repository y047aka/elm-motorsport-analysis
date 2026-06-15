module Motorsport.Widget.Compare exposing (viewComparison)

{-| 車両の詳細情報(サマリー＋クラス内ポジション履歴)を表示する Widget.
ポップオーバー/ダイアログの中身として使う想定で, ポップオーバー属性自体は持たない.

`viewComparison` はモーダル内に同一クラスの車両セレクタを備え, 最大3台までを
トグル選択しながら比較できる. サマリーを横並びにし, ポジション履歴チャートは
1枚に全車を強調表示する(同一クラス前提).

@docs viewComparison

-}

import Css exposing (num, opacity, property)
import Html.Styled exposing (Html, button, div, img, text)
import Html.Styled.Attributes exposing (class, css, src)
import Html.Styled.Events exposing (onClick)
import List.Extra
import Motorsport.Car exposing (Status(..))
import Motorsport.Class as Class exposing (Class)
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Lap.Performance as Performance
import Motorsport.Manufacturer as Manufacturer exposing (Manufacturer)
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
import Motorsport.Widget.Compare.PositionProgression as PositionProgression


carSummary : Int -> StandingsEntry -> Html msg
carSummary season item =
    div
        [ css
            [ property "display" "grid"
            , property "row-gap" "12px"
            , property "align-content" "start"
            ]
        ]
        [ header season item
        , summaryStats item
        ]


{-| モーダル内で同一クラスの車両を最大3台までトグル選択しながら比較するビュー.
`selectedCarNumbers` は選択中の車番(先頭をチャートのクラス基準とする).
セレクタの各チップは `onToggleCar` を発火する(3台上限の制御は呼び出し側で行う).
-}
viewComparison :
    { season : Int, clock : Clock.Model, onToggleCar : String -> msg }
    -> Standings
    -> List String
    -> Html msg
viewComparison { season, clock, onToggleCar } standings selectedCarNumbers =
    let
        entriesByNumber =
            Standings.toList standings

        selectedEntries =
            selectedCarNumbers
                |> List.filterMap
                    (\carNumber ->
                        List.Extra.find (\e -> e.metadata.carNumber == carNumber) entriesByNumber
                    )
    in
    case selectedEntries of
        [] ->
            text ""

        first :: _ ->
            div
                [ css
                    [ property "display" "grid"
                    , property "row-gap" "12px"
                    ]
                ]
                [ carSelector onToggleCar standings first.metadata.class selectedCarNumbers
                , div
                    [ css
                        [ property "display" "grid"
                        , property "grid-template-columns" ("repeat(" ++ String.fromInt (List.length selectedEntries) ++ ", minmax(0, 1fr))")
                        , property "column-gap" "16px"
                        ]
                    ]
                    (List.map (carSummary season) selectedEntries)
                , PositionProgression.view
                    { width = 600, height = 200 }
                    clock
                    standings
                    { class = first.metadata.class
                    , highlighted = selectedCarNumbers
                    }
                ]


{-| 指定クラスの全車両をチップとして並べ, クリックで選択をトグルするセレクタ.
-}
carSelector : (String -> msg) -> Standings -> Class -> List String -> Html msg
carSelector onToggleCar standings class selectedCarNumbers =
    let
        classCars =
            Standings.toClassList standings
                |> List.Extra.find (\( class_, _ ) -> class_ == class)
                |> Maybe.map Tuple.second
                |> Maybe.withDefault []
    in
    div
        [ css
            [ property "display" "flex"
            , property "flex-wrap" "wrap"
            , property "gap" "6px"
            ]
        ]
        (List.map
            (\item ->
                carSelectorChip onToggleCar
                    (List.member item.metadata.carNumber selectedCarNumbers)
                    item
            )
            classCars
        )


carSelectorChip : (String -> msg) -> Bool -> StandingsEntry -> Html msg
carSelectorChip onToggleCar isSelected item =
    let
        manufacturerColor =
            Manufacturer.toColor item.metadata.manufacturer
    in
    button
        [ onClick (onToggleCar item.metadata.carNumber)
        , css
            [ property "display" "flex"
            , property "align-items" "center"
            , property "column-gap" "4px"
            , property "padding" "2px 8px"
            , property "border-radius" "9999px"
            , property "font-size" "11px"
            , property "font-weight" "700"
            , property "font-variant-numeric" "tabular-nums"
            , property "cursor" "pointer"
            , property "color" "inherit"
            , property "font-family" "inherit"
            , if isSelected then
                Css.batch
                    [ property "border" ("1px solid " ++ manufacturerColor.value)
                    , property "background-color" ("oklch(from " ++ manufacturerColor.value ++ "l c h / 0.3)")
                    ]

              else
                Css.batch
                    [ property "border" "1px solid hsl(0 0% 100% / 0.2)"
                    , property "background-color" "transparent"
                    , opacity (num 0.7)
                    ]
            ]
        ]
        [ text ("#" ++ item.metadata.carNumber) ]


header : Int -> StandingsEntry -> Html msg
header season item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr auto"
            , property "align-items" "center"
            , property "column-gap" "12px"
            ]
        ]
        [ carNumberBadge item
        , div
            [ css
                [ property "display" "grid"
                , property "row-gap" "2px"
                ]
            ]
            [ div
                [ css
                    [ property "font-size" "14px"
                    , property "font-weight" "700"
                    ]
                ]
                [ text item.metadata.team ]
            , div
                [ css
                    [ property "font-size" "11px"
                    , opacity (num 0.7)
                    ]
                ]
                [ text (item.metadata.drivers |> List.map .name |> String.join " / ") ]
            ]
        , div
            [ css
                [ property "display" "grid"
                , property "justify-items" "end"
                , property "row-gap" "4px"
                ]
            ]
            [ classBadge season item
            , statusBadge item.status
            ]
        ]


carNumberBadge : StandingsEntry -> Html msg
carNumberBadge item =
    let
        manufacturerColor =
            Manufacturer.toColor item.metadata.manufacturer
    in
    div
        [ class "stat p-1 place-items-center gap-1.5 rounded"
        , css
            [ property "width" "35px"
            , property "background-color" ("oklch(from " ++ manufacturerColor.value ++ "l c h)")
            , property "border" "none"
            ]
        ]
        [ manufacturerLogo item.metadata.manufacturer
        , div [ class "stat-value text-xs leading-none" ]
            [ text item.metadata.carNumber ]
        ]


manufacturerLogo : Manufacturer -> Html msg
manufacturerLogo manufacturer =
    case Manufacturer.toLogoUrl manufacturer of
        Just url ->
            img
                [ src url
                , css
                    [ property "max-width" "28px"
                    , property "height" "16px"
                    , property "object-fit" "contain"
                    , property "opacity" "0.9"
                    ]
                ]
                []

        Nothing ->
            div
                [ css
                    [ property "max-width" "28px"
                    , property "height" "16px"
                    ]
                ]
                []


classBadge : Int -> StandingsEntry -> Html msg
classBadge season item =
    div
        [ css
            [ property "display" "flex"
            , property "align-items" "center"
            , property "column-gap" "4px"
            , property "font-size" "11px"
            , property "font-weight" "700"
            , Css.before
                [ property "display" "block"
                , property "content" (Css.qt "")
                , property "width" "0.2em"
                , property "height" "1em"
                , property "border-radius" "2px"
                , Css.backgroundColor (Class.toHexColor season item.metadata.class)
                ]
            ]
        ]
        [ text (Class.toString item.metadata.class) ]


statusBadge : Status -> Html msg
statusBadge status =
    case status of
        InPit ->
            div
                [ css
                    [ property "display" "grid"
                    , property "place-items" "center"
                    , property "padding" "1px 6px"
                    , property "border-radius" "9999px"
                    , property "border" "1px solid hsl(0 0% 100% / 0.6)"
                    , property "font-size" "9px"
                    , property "font-weight" "700"
                    ]
                ]
                [ text "IN PIT" ]

        Retired ->
            div
                [ css
                    [ property "padding" "1px 6px"
                    , property "border-radius" "3px"
                    , property "background-color" "hsl(0 70% 45%)"
                    , property "font-size" "9px"
                    , property "font-weight" "700"
                    , property "letter-spacing" "0.05em"
                    ]
                ]
                [ text "RETIRED" ]

        _ ->
            text ""


summaryStats : StandingsEntry -> Html msg
summaryStats item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "repeat(auto-fit, minmax(56px, 1fr))"
            , property "gap" "8px"
            ]
        ]
        [ statCell "Position" (text ("P" ++ String.fromInt item.position))
        , statCell "In Class" (text ("P" ++ String.fromInt item.positionInClass))
        , statCell "Laps" (text (String.fromInt item.lapsCompleted))
        , statCell "Gap" (text (Gap.toString item.gapToLeader))
        , statCell "Interval" (text (Gap.toString item.intervalToAhead))
        , statCell "Best Lap" (ratedTimeCell item.bestLap)
        ]


statCell : String -> Html msg -> Html msg
statCell label valueHtml =
    div
        [ class "rounded bg-base-300 p-2"
        , css
            [ property "display" "grid"
            , property "row-gap" "2px"
            , property "justify-items" "center"
            ]
        ]
        [ div
            [ css
                [ property "font-size" "9px"
                , opacity (num 0.6)
                ]
            ]
            [ text label ]
        , div
            [ css
                [ property "font-size" "12px"
                , property "font-variant-numeric" "tabular-nums"
                ]
            ]
            [ valueHtml ]
        ]


ratedTimeCell : Maybe Performance.RatedTime -> Html msg
ratedTimeCell ratedTime =
    case ratedTime of
        Just { time, performance } ->
            div
                [ css
                    [ if Performance.isStandard performance then
                        Css.batch []

                      else
                        property "color" (Performance.toColorVariable performance)
                    ]
                ]
                [ text (Duration.toString time) ]

        Nothing ->
            text "-"
