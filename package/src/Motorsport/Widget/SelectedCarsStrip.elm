module Motorsport.Widget.SelectedCarsStrip exposing (view)

{-| その瞬間の総合上位数台について、直前ラップの確定値・ベスト・セクター成績を
横並びカードで表示する Widget. 選択操作なしでレース先頭の状況を俯瞰できる.

@docs view

-}

import Css exposing (backgroundColor, before, num, opacity, property, qt)
import Dict
import Html.Styled exposing (Html, button, div, text)
import Html.Styled.Attributes as Attributes exposing (class, css)
import Html.Styled.Events exposing (onClick)
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Car exposing (Status(..))
import Motorsport.Class as Class
import Motorsport.Gap as Gap
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
import Motorsport.Widget.CarStatus as CarStatus
import Motorsport.Widget.Sparkline as Sparkline


{-| `offset` は表示ウィンドウの先頭順位(0始まり). `onScrollTo` には移動先 offset を渡す.
範囲外の offset は内部でクランプされるため, 呼び出し側はそのまま保持してよい.
-}
view :
    { season : Int
    , analysis : Analysis
    , offset : Int
    , onScrollTo : Int -> msg
    }
    -> Standings
    -> Html msg
view config standings =
    let
        allCars =
            Standings.toList standings

        maxOffset =
            max 0 (List.length allCars - displayCount)

        offset =
            clamp 0 maxOffset config.offset

        window =
            allCars
                |> List.drop offset
                |> List.take displayCount
    in
    case window of
        [] ->
            emptyState

        _ ->
            div
                [ css
                    [ property "display" "grid"
                    , property "grid-template-columns" "auto 1fr auto"
                    , property "align-items" "center"
                    , property "column-gap" "8px"
                    ]
                ]
                [ navButton "◀" (config.onScrollTo (offset - 1)) (offset <= 0)
                , div
                    [ css
                        [ property "display" "grid"
                        , property "grid-auto-flow" "column"
                        , property "grid-auto-columns" "minmax(0, 1fr)"
                        , property "column-gap" "8px"
                        ]
                    ]
                    (List.map
                        (\item ->
                            carCard
                                { season = config.season, analysis = config.analysis }
                                standings
                                (findNeighbors allCars item)
                                item
                        )
                        window
                    )
                , navButton "▶" (config.onScrollTo (offset + 1)) (offset >= maxOffset)
                ]


{-| 同時表示する台数. カルーセルは1台ずつスクロールする.
-}
displayCount : Int
displayCount =
    5


navButton : String -> msg -> Bool -> Html msg
navButton label msg isDisabled =
    button
        [ onClick msg
        , Attributes.disabled isDisabled
        , class "btn btn-circle btn-sm text-xs"
        ]
        [ text label ]


emptyState : Html msg
emptyState =
    div
        [ css
            [ property "display" "grid"
            , property "place-items" "center"
            , property "font-size" "11px"
            , opacity (num 0.5)
            ]
        ]
        [ text "No cars on track" ]


{-| 同一クラス順位で前後に隣接するクルマ. 直前/直後から順に最大2台ずつ保持する
(`ahead = [A1, A2]`, `behind = [B1, B2]`). 表示は直近の1台ずつ(`List.head`)を,
基準母集団は2台ずつ全部を使う. 先頭/最後尾やクラス端では台数が減る.
-}
type alias Neighbors =
    { ahead : List StandingsEntry
    , behind : List StandingsEntry
    }


{-| 同一クラス内の順位で `item` の前後に位置するクルマを最大2台ずつ取り出す.
総合順位リストはクラスでフィルタしても順序が保たれるため, そのままクラス内順位になる.
クラス端では取れる台数だけ返す(範囲外インデックスは除外される).
-}
findNeighbors : List StandingsEntry -> StandingsEntry -> Neighbors
findNeighbors allCars item =
    let
        classmates =
            allCars |> List.filter (\e -> e.metadata.class == item.metadata.class)
    in
    case List.Extra.findIndex (\e -> e.metadata.carNumber == item.metadata.carNumber) classmates of
        Just i ->
            { ahead = [ 1, 2 ] |> List.filterMap (\d -> List.Extra.getAt (i - d) classmates)
            , behind = [ 1, 2 ] |> List.filterMap (\d -> List.Extra.getAt (i + d) classmates)
            }

        Nothing ->
            { ahead = [], behind = [] }


carCard : { season : Int, analysis : Analysis } -> Standings -> Neighbors -> StandingsEntry -> Html msg
carCard { season, analysis } standings neighbors item =
    div
        [ css
            [ property "display" "grid"
            , property "row-gap" "4px"
            ]
        ]
        [ div
            [ css
                [ property "padding-inline" "8px"
                , property "display" "grid"
                , property "grid-template-columns" "auto 1fr auto"
                , property "column-gap" "16px"
                ]
            ]
            [ positionLabel season item
            , gapsRow item
            , statusBadge item.status
            ]
        , div [ class "card bg-base-200" ]
            [ div
                [ class "card-body p-3"
                , css
                    [ property "display" "grid"
                    , property "row-gap" "8px"
                    ]
                ]
                [ cardHeader item
                , CarStatus.sectorAndLaps analysis item
                , rivalGapSparkline standings neighbors item
                ]
            ]
        ]


cardHeader : StandingsEntry -> Html msg
cardHeader item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr"
            , property "align-items" "center"
            , property "column-gap" "8px"
            ]
        ]
        [ CarStatus.carNumberBadge item
        , div
            [ css
                [ property "font-size" "12px"
                , property "white-space" "nowrap"
                , property "overflow" "hidden"
                , property "text-overflow" "ellipsis"
                ]
            ]
            [ text (item.currentDriver |> Maybe.map (.name >> formatDriverName) |> Maybe.withDefault "") ]
        ]


statusBadge : Status -> Html msg
statusBadge status =
    case status of
        InPit ->
            div
                [ css
                    [ property "display" "grid"
                    , property "place-items" "center"
                    , property "width" "16px"
                    , property "height" "16px"
                    , property "border-radius" "9999px"
                    , property "border" "1px solid hsl(0 0% 100% / 0.6)"
                    , property "font-size" "9px"
                    , property "font-weight" "700"
                    , property "line-height" "1"
                    ]
                ]
                [ text "P" ]

        Retired ->
            div
                [ css
                    [ property "padding" "1px 4px"
                    , property "border-radius" "3px"
                    , property "background-color" "hsl(0 70% 45%)"
                    , property "font-size" "9px"
                    , property "font-weight" "700"
                    , property "letter-spacing" "0.05em"
                    ]
                ]
                [ text "RET" ]

        _ ->
            text ""


positionLabel : Int -> StandingsEntry -> Html msg
positionLabel season item =
    div
        [ css
            [ property "display" "flex"
            , property "align-items" "center"
            , property "column-gap" "4px"
            , property "font-size" "10px"
            , before
                [ property "display" "block"
                , property "content" (qt "")
                , property "width" "0.2em"
                , property "height" "1em"
                , property "border-radius" "2px"
                , backgroundColor (Class.toHexColor season item.metadata.class)
                ]
            ]
        ]
        [ text ("P" ++ String.fromInt item.position) ]


gapsRow : StandingsEntry -> Html msg
gapsRow item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "1fr"
            , property "align-items" "baseline"
            , property "font-size" "10px"
            , opacity (num 0.75)
            ]
        ]
        [ gapCell "Interval" item.intervalToAhead ]


gapCell : String -> Gap.Gap -> Html msg
gapCell label gap =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr"
            , property "align-items" "baseline"
            , property "column-gap" "4px"
            , property "font-variant-numeric" "tabular-nums"
            ]
        ]
        [ div [ css [ opacity (num 0.7) ] ]
            [ text label ]
        , div
            [ css [ property "text-align" "right" ] ]
            [ text (Gap.toString gap) ]
        ]



-- RIVAL GAP (sparkline)


{-| 前後のライバルとの位置関係を, 近傍最大5台(対象車＋前後2台ずつ)のラップ平均を基準
(中央の0ライン=点線)にした相対ギャップの推移で表示する. 各ラップ番号での
`各車の累積タイム − グループ平均の累積タイム` をギャップとし, 表示するのは直前車・対象車・
直後車の3本(マニュファクチャラー色). 対象車だけは太線＋不透明で強調する.

線の傾きが相対ペース, レベルが相対順位を表し, 上がれば(累積タイムが基準より小さい=)
相対的にリードを広げ, 下がれば縮めたことを示す. 2線の差(=収束/発散の読み)は基準の取り方に
不変なので, 基準を5台に広げても前後ライバルとの詰め具合の読みは変わらない. 5台基準は
3台基準の厳密な自己センタリング(3本の和=0)を近似的なものへ緩め, 前後線の鏡像ロックを
解く効果を持つ(外側2台のギャップは概ね相殺するため構図は0近傍に留まる).

基準は各車の非ピットラップ(pitTime なし)だけで平均し, ピットによる基準の跳ねを防ぐ.
縦軸はピット等の外れ値(両側 IQR)を除いた通常変動の帯だけで張り, 外れ値は枠外へ
クリップする. 前後ライバルが両方欠けるカードは描画しない.

ラップ列は対象車の現在ラップを起点に直近20ラップの窓で全車そろえて切り出す.
基準・ギャップともラップ番号で突き合わせるため, 隣接車が対象車と同一周回にいる
(クラス内隣接なら通常成り立つ)ことを前提とする. 周回遅れの隣接車は同一ラップ番号の
累積タイム差が約1ラップ分となり, IQR の外れ値として帯の外へクリップされる.

-}
rivalGapSparkline : Standings -> Neighbors -> StandingsEntry -> Html msg
rivalGapSparkline standings neighbors item =
    let
        -- 各車の CarLine は対象車の現在ラップを窓の起点として一度だけ算出して使い回す.
        currentLap =
            item.lapsCompleted

        aheadLines =
            neighbors.ahead |> List.map (Sparkline.toCarLine standings currentLap False)

        behindLines =
            neighbors.behind |> List.map (Sparkline.toCarLine standings currentLap False)

        focusedLine =
            Sparkline.toCarLine standings currentLap True item

        -- 表示は直近の前後1台ずつ＋対象車の3本(前車 → 対象車 → 後車). 隣が欠ければ除外.
        cars =
            List.filterMap identity [ List.head aheadLines, Just focusedLine, List.head behindLines ]

        -- 描画ガード用. 前後ライバルが両方欠けるカードはギャップ比較が成立しないため描かない.
        rivalLines =
            List.filterMap identity [ List.head aheadLines, List.head behindLines ]

        -- 基準母集団は前後2台ずつ＋対象車の最大5台. 表示3本とは分離する.
        referenceCars =
            aheadLines ++ focusedLine :: behindLines

        -- 「ラップ番号 → 近傍最大5台(対象車を含む)の非ピット平均 elapsed」.
        referenceByLap =
            Sparkline.groupReferenceByLap referenceCars

        -- 各車のギャップ点列を一度だけ算出して保持する(描画で共用).
        carsWithGaps =
            cars |> List.map (\car -> { car = car, points = Sparkline.gapPoints referenceByLap car.laps })

        focusedLapNumbers =
            focusedLine.laps |> List.map (.lap >> toFloat)
    in
    case ( focusedLapNumbers, rivalLines, Dict.isEmpty referenceByLap ) of
        ( _ :: _ :: _, _ :: _, False ) ->
            Sparkline.gapChartView
                { width = Sparkline.sparklineWidth
                , height = rivalSparkHeight
                , xRange =
                    ( List.minimum focusedLapNumbers |> Maybe.withDefault 0
                    , List.maximum focusedLapNumbers |> Maybe.withDefault 1
                    )
                }
                carsWithGaps

        _ ->
            text ""


rivalSparkHeight : Float
rivalSparkHeight =
    36


formatDriverName : String -> String
formatDriverName fullName =
    case String.words fullName of
        first :: rest ->
            first :: (rest |> List.map String.toUpper) |> String.join " "

        [] ->
            fullName
