module Motorsport.Chart.Common exposing
    ( Emphasis(..), chooseByEmphasis
    , LapWindow(..)
    , Dimensions
    , LineScales
    , iqrFences, upperFence
    )

{-| 複数のチャートが共有する土台. 系列の強調(`Emphasis`), ラップ列の窓(`LapWindow`),
描画寸法(`Dimensions`), 折れ線描画のスケール一式(`LineScales`)といった型に加え,
外れ値処理の統計ヘルパ(`iqrFences` / `upperFence`)をまとめる. スパークライン・ラップタイム
分布・ポジション履歴などから参照する.

@docs Emphasis, chooseByEmphasis
@docs LapWindow
@docs Dimensions
@docs LineScales
@docs iqrFences, upperFence

-}

import Scale


{-| 系列(折れ線)の強調. `Focused` は対象車(太線・不透明・大ドット), `Muted` は周辺車
(細線・半透明・小ドット)を表す. 真偽値による分岐(boolean blindness)を避ける.
-}
type Emphasis
    = Focused
    | Muted


{-| 強調に応じて値を選ぶ. `Focused` なら `.focused`, `Muted` なら `.muted` を返す.
線幅や不透明度の分岐をチャート間で同じ形に書ける.
-}
chooseByEmphasis : { focused : a, muted : a } -> Emphasis -> a
chooseByEmphasis { focused, muted } emphasis =
    case emphasis of
        Focused ->
            focused

        Muted ->
            muted


{-| ラップ列の切り出し方. `Recent` は対象車の現在ラップを起点とした直近20周の窓
(リタイア済み・大きく遅れた隣接車の古いラップが基準平均に混入するのを防ぐ).
`Range` はポジション履歴と揃えた確定ラップ範囲 `(minLap, maxLap)`.
-}
type LapWindow
    = Recent Int
    | Range ( Int, Int )


{-| チャートの viewBox 寸法とパディング. 種類ごとのプリセットは各チャート側で定義する.
-}
type alias Dimensions =
    { width : Float
    , height : Float
    , padX : Float
    , padY : Float
    }


{-| 折れ線1本を描くためのスケール一式. X/Y のスケールと, 表示範囲の判定に使う
X軸の端 `minX`/`maxX`, 縦軸の帯内判定 `inBand` をまとめる.
-}
type alias LineScales =
    { xScale : Scale.ContinuousScale Float
    , yScale : Scale.ContinuousScale Float
    , minX : Float
    , maxX : Float
    , inBand : Int -> Bool
    }


{-| 昇順ソート済みリストの q 分位点(0〜1)を最近傍で返す.
-}
quantile : Float -> List Int -> Maybe Int
quantile q sorted =
    let
        n =
            List.length sorted
    in
    if n == 0 then
        Nothing

    else
        let
            idx =
                clamp 0 (n - 1) (floor (toFloat (n - 1) * q))
        in
        sorted |> List.drop idx |> List.head


{-| 昇順ソート済みリストの IQR 外れ値フェンス `[Q1 − 1.5×IQR, Q3 + 1.5×IQR]`.
要素が空のときは `Nothing`.

    iqrFences [ 1, 2, 3, 4, 5, 6, 7, 8 ]
    --> Just { lower = -4, upper = 12 }

-}
iqrFences : List Int -> Maybe { lower : Int, upper : Int }
iqrFences sorted =
    Maybe.map2
        (\q1 q3 ->
            let
                margin =
                    round (1.5 * toFloat (q3 - q1))
            in
            { lower = q1 - margin, upper = q3 + margin }
        )
        (quantile 0.25 sorted)
        (quantile 0.75 sorted)


{-| 外れ値の上側フェンス `Q3 + 1.5×IQR`. レーシング帯の上限として使う. 値が少なく
フェンスを求められないときは最大値へフォールバックする(空リストでは 0). 入力はソート不要.

    upperFence [ 1, 2, 3, 4, 5, 6, 7, 8 ]
    --> 12

-}
upperFence : List Int -> Int
upperFence values =
    iqrFences (List.sort values)
        |> Maybe.map .upper
        |> Maybe.withDefault (List.maximum values |> Maybe.withDefault 0)
