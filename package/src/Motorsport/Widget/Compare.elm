module Motorsport.Widget.Compare exposing (viewComparison)

{-| 車両の詳細情報(サマリー＋クラス内ポジション履歴)を表示する Widget.
ポップオーバー/ダイアログの中身として使う想定で, ポップオーバー属性自体は持たない.

`viewComparison` はモーダル内に同一クラスの車両セレクタを備え, 最大3台までを
トグル選択しながら比較できる. サマリーを横並びにし, ポジション履歴チャートは
1枚に全車を強調表示する(同一クラス前提).

@docs viewComparison

-}

import Css exposing (num, opacity, property)
import Html.Styled exposing (Html, button, div, text)
import Html.Styled.Attributes exposing (css)
import Html.Styled.Events exposing (onClick)
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Car exposing (Status(..))
import Motorsport.Class as Class exposing (Class)
import Motorsport.Clock as Clock
import Motorsport.Gap as Gap
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
import Motorsport.Widget.CarStatus as CarStatus
import Motorsport.Widget.Compare.PositionProgression as PositionProgression
import Motorsport.Widget.Sparkline as Sparkline


{-| 比較できる車両の最大台数. サマリーのスロット数(プレースホルダ含む)もこれに揃える.
-}
maxComparisonCars : Int
maxComparisonCars =
    3


{-| モーダルのグラスモーフィズムに馴染む半透明パネル. モーダル本体(ダイアログ表面)
の上に重なる前提で, 白を薄く敷いて1段持ち上げる. 塗り/縁取りの色は app 側の
DaisyUI テーマトークン(`--glass-panel-bg` / `--glass-panel-border`)で管理する.
-}
glassPanel : Css.Style
glassPanel =
    Css.batch
        [ property "background-color" "var(--glass-panel-bg)"
        , property "border" "1px solid var(--glass-panel-border)"
        , property "border-radius" "8px"
        ]


{-| 未選択スロットを埋める控えめなプレースホルダ. 上のセレクタへ誘導する.
-}
placeholderCard : Html msg
placeholderCard =
    div
        [ css
            [ property "display" "grid"
            , property "place-items" "center"
            , property "min-height" "100px"
            , property "border" "1px dashed hsl(0 0% 100% / 0.15)"
            , property "border-radius" "8px"
            , property "font-size" "11px"
            , property "color" "hsl(0 0% 100% / 0.35)"
            ]
        ]
        [ text "車両を追加" ]


carSummary : Analysis -> Maybe ( Int, Int ) -> Standings -> StandingsEntry -> Html msg
carSummary analysis lapRange standings item =
    div
        [ css
            [ property "display" "grid"
            , property "row-gap" "12px"
            , property "align-content" "start"
            ]
        ]
        [ header item
        , summaryStats analysis item
        , lapTimeCard lapRange standings item
        ]


{-| 各車サマリーに含める「Lap time」カード. 絶対ラップタイムの推移を1台分の折れ線で描く.
X軸はポジション履歴と同じラップ範囲に揃える.
-}
lapTimeCard : Maybe ( Int, Int ) -> Standings -> StandingsEntry -> Html msg
lapTimeCard maybeRange standings item =
    chartPanel "Lap time" <|
        case maybeRange of
            Just range ->
                Sparkline.lapTimeSparkline range standings item

            Nothing ->
                text ""


{-| モーダル内で同一クラスの車両を最大3台までトグル選択しながら比較するビュー.
`selectedCarNumbers` は選択中の車番(先頭をチャートのクラス基準とする).
セレクタの各チップは `onToggleCar` を発火する(3台上限の制御は呼び出し側で行う).
-}
viewComparison :
    { season : Int, analysis : Analysis, clock : Clock.Model, onToggleCar : String -> msg }
    -> Standings
    -> List String
    -> Html msg
viewComparison { season, analysis, clock, onToggleCar } standings selectedCarNumbers =
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
            let
                class =
                    first.metadata.class

                lapRange =
                    PositionProgression.lapRange clock standings class
            in
            div
                [ css
                    [ property "display" "grid"
                    , property "row-gap" "12px"
                    ]
                ]
                [ div
                    [ css
                        [ property "display" "flex"
                        , property "align-items" "center"
                        , property "column-gap" "12px"
                        ]
                    ]
                    [ classBadge season class
                    , carSelector onToggleCar standings class selectedCarNumbers
                    ]
                , div
                    [ css
                        [ property "display" "grid"
                        , property "grid-template-columns" ("repeat(" ++ String.fromInt maxComparisonCars ++ ", minmax(0, 1fr))")
                        , property "column-gap" "16px"
                        ]
                    ]
                    (List.map (carSummary analysis lapRange standings) selectedEntries
                        ++ List.repeat (maxComparisonCars - List.length selectedEntries) placeholderCard
                    )
                , gapPanel lapRange standings selectedEntries
                , chartPanel "Position progression" <|
                    PositionProgression.view
                        { width = 800, height = 200 }
                        clock
                        standings
                        { class = class
                        , highlighted = selectedCarNumbers
                        }
                ]


{-| 「Gap to group avg」見出し付きのパネル. 選択車のグループ平均を基準にした相対ギャップを
1枚に統合表示する.
-}
gapPanel : Maybe ( Int, Int ) -> Standings -> List StandingsEntry -> Html msg
gapPanel maybeRange standings entries =
    chartPanel "Gap to group avg" <|
        case maybeRange of
            Just range ->
                Sparkline.gapSparkline range standings entries

            Nothing ->
                text ""


{-| 見出し付きのチャートパネル. 見出しは小型・大文字で控えめに付ける.
-}
chartPanel : String -> Html msg -> Html msg
chartPanel label content =
    div
        [ css
            [ glassPanel
            , property "padding" "8px"
            , property "display" "grid"
            , property "row-gap" "6px"
            ]
        ]
        [ div
            [ css
                [ property "font-size" "9px"
                , property "text-transform" "uppercase"
                , property "letter-spacing" "0.05em"
                , opacity (num 0.5)
                ]
            ]
            [ text label ]
        , content
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


header : StandingsEntry -> Html msg
header item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr auto"
            , property "align-items" "start"
            , property "column-gap" "12px"
            ]
        ]
        [ CarStatus.carNumberBadge item
        , div
            [ css
                [ property "display" "grid"
                , property "row-gap" "2px"
                ]
            ]
            [ div [ css [ property "font-size" "14px" ] ]
                [ text item.metadata.team ]
            , div
                [ css
                    [ property "font-size" "11px"
                    , opacity (num 0.7)
                    ]
                ]
                [ text (item.metadata.drivers |> List.map .name |> String.join " / ") ]
            ]
        , statusBadge item.status
        ]


classBadge : Int -> Class -> Html msg
classBadge season class =
    div
        [ css
            [ property "display" "flex"
            , property "align-items" "center"
            , property "column-gap" "4px"
            , property "font-size" "11px"
            , property "font-weight" "700"
            , property "white-space" "nowrap"
            , Css.before
                [ property "display" "block"
                , property "content" (Css.qt "")
                , property "width" "0.2em"
                , property "height" "1em"
                , property "border-radius" "2px"
                , Css.backgroundColor (Class.toHexColor season class)
                ]
            ]
        ]
        [ text (Class.toString class) ]


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


summaryStats : Analysis -> StandingsEntry -> Html msg
summaryStats analysis item =
    div
        [ css
            [ property "display" "grid"
            , property "row-gap" "12px"
            ]
        ]
        [ div
            [ css
                [ glassPanel
                , property "display" "grid"
                , property "grid-template-columns" "repeat(5, minmax(0, 1fr))"
                ]
            ]
            [ statCell "Pos" (text ("P" ++ String.fromInt item.position))
            , statCell "Class" (text ("P" ++ String.fromInt item.positionInClass))
            , statCell "Laps" (text (String.fromInt item.lapsCompleted))
            , statCell "Gap" (text (Gap.toString item.gapToLeader))
            , statCell "Int" (text (Gap.toString item.intervalToAhead))
            ]
        , div
            [ css
                [ glassPanel
                , property "padding" "8px"
                ]
            ]
            [ CarStatus.sectorAndLaps analysis item ]
        ]


{-| 順位・ギャップ系を1枚のストリップに詰める用の小型セル.
セル間は左の区切り線で仕切る(先頭セルは区切り線なし).
-}
statCell : String -> Html msg -> Html msg
statCell label valueHtml =
    div
        [ css
            [ property "display" "grid"
            , property "row-gap" "1px"
            , property "justify-items" "center"
            , property "padding" "4px 2px"
            , property "border-left" "1px solid hsl(0 0% 100% / 0.05)"
            , Css.firstChild [ property "border-left" "none" ]
            ]
        ]
        [ div
            [ css
                [ property "font-size" "8px"
                , property "text-transform" "uppercase"
                , property "letter-spacing" "0.03em"
                , opacity (num 0.5)
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
