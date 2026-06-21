module Motorsport.Chart.Common exposing
    ( Emphasis(..), chooseByEmphasis
    , LapWindow(..)
    , Dimensions
    , Scales, svg, renderLine
    , axisStyle, lapGridLines, lapAxis, yAxis
    , iqrFences, upperFence
    )

{-| 複数のチャートが共有する土台. 系列の強調(`Emphasis`), ラップ列の窓(`LapWindow`),
描画寸法(`Dimensions`), 折れ線描画のスケール(`Scales`)といった型と, それらを使って
1系列の折れ線＋終端ドットを描く共通レンダラ(`renderLine`), 軸・グリッドの共通描画
(`axisStyle` / `lapGridLines` / `lapAxis` / `yAxis`), 外れ値処理の統計ヘルパ
(`iqrFences` / `upperFence`)をまとめる. スパークライン・ラップタイム分布・ポジション履歴
などから参照する.

@docs Emphasis, chooseByEmphasis
@docs LapWindow
@docs Dimensions
@docs Scales, svg, renderLine
@docs axisStyle, lapGridLines, lapAxis, yAxis
@docs iqrFences, upperFence

-}

import Axis exposing (tickFormat, tickPadding, tickSizeInner, tickSizeOuter, ticks)
import Css
import Css.Extra
import Css.Global exposing (descendants, each)
import List.Extra
import Path.Styled as Path
import Scale
import Shape
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, line, text, text_)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Transform(..))


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


{-| チャートの viewBox 寸法と上下左右のパディング(`padding.top` 等). 軸ラベルのために
左・下を厚く取るチャート(ポジション履歴)と, 対称パディングのチャート(スパークライン)を
同じ型で表す. 種類ごとのプリセットは各チャート側で定義する.
-}
type alias Dimensions =
    { width : Float
    , height : Float
    , padding :
        { top : Float
        , right : Float
        , bottom : Float
        , left : Float
        }
    }


{-| 折れ線を描くためのスケール一式. 各チャートで `allPoints` から1度だけ構築し,
軸・グリッド・各系列の描画へ配る(系列ごとの再構築を避ける).
-}
type alias Scales =
    { xScale : Scale.ContinuousScale Float
    , yScale : Scale.ContinuousScale Float
    }


{-| チャート共通の svg ラッパ. 幅100%・block 表示で `viewBox` を寸法に張り, 装飾と
各系列の折れ線をまとめて描く. 装飾(軸・グリッド・ゼロ線など)は各チャートが渡す.
-}
svg : { width : Float, height : Float } -> List (Svg msg) -> Svg msg
svg { width, height } children =
    Svg.Styled.svg
        [ SvgAttr.width "100%"
        , SvgAttr.css [ Css.property "display" "block" ]
        , viewBox 0 0 width height
        ]
        children


{-| 1系列分の折れ線＋終端ドットを描く共通レンダラ. `points` は `( x, y )` の整数値
(ラップ番号と縦軸量)で渡し, `Scales` で画面座標へ投影する. 表示は X軸スケールの
ドメイン(`Scale.domain`)内に収め, はみ出す点はクリップする. 線の太さ・不透明度は
`Emphasis` で決め, 終端ドットは強調系列(`Focused`)の最終点にだけ置く. `label`(車両番号など)
が空文字列でなければ終端ドットの右側に併記する.
-}
renderLine :
    Scales
    -> { color : Css.Color, emphasis : Emphasis, label : String, points : List ( Int, Int ) }
    -> Svg msg
renderLine { xScale, yScale } { color, emphasis, label, points } =
    let
        ( minX, maxX ) =
            Scale.domain xScale

        visible =
            points |> List.filter (\( x, _ ) -> minX <= toFloat x && toFloat x <= maxX)

        project ( x, y ) =
            ( Scale.convert xScale (toFloat x), Scale.convert yScale (toFloat y) )

        linePath =
            visible |> List.map (project >> Just) |> Shape.line Shape.linearCurve

        terminalDot =
            case emphasis of
                Focused ->
                    visible
                        |> List.Extra.last
                        |> Maybe.map
                            (\point ->
                                let
                                    ( px, py ) =
                                        project point
                                in
                                g []
                                    (circle
                                        [ InPx.cx px
                                        , InPx.cy py
                                        , InPx.r terminalDotRadius
                                        , SvgAttr.css [ Css.fill color ]
                                        ]
                                        []
                                        :: (if String.isEmpty label then
                                                []

                                            else
                                                [ terminalLabel { x = px, y = py, color = color, label = label } ]
                                           )
                                    )
                            )
                        |> Maybe.withDefault (g [] [])

                Muted ->
                    g [] []
    in
    g []
        [ Path.element linePath
            [ SvgAttr.stroke color.value
            , SvgAttr.strokeWidth (chooseByEmphasis { focused = "2", muted = "1.5" } emphasis)
            , SvgAttr.strokeOpacity (chooseByEmphasis { focused = "1", muted = "0.4" } emphasis)
            , SvgAttr.fill "none"
            ]
        , terminalDot
        ]


{-| 終端ドットの右側に併記するラベル(車両番号など). 描画可否は呼び出し側(`renderLine`)で
分岐する. ドットと重ならないよう半径ぶん右へ寄せ, 縦は中央に揃える.
-}
terminalLabel : { x : Float, y : Float, color : Css.Color, label : String } -> Svg msg
terminalLabel { x, y, color, label } =
    text_
        [ InPx.x (x + terminalDotRadius + 3)
        , InPx.y y
        , SvgAttr.dominantBaseline "central"
        , SvgAttr.css
            [ Css.fill color
            , Css.fontSize (Css.px 9)
            , Css.fontWeight Css.bold
            ]
        ]
        [ text label ]


{-| 終端ドットの半径. 強調系列の最新点を示す.
-}
terminalDotRadius : Float
terminalDotRadius =
    2.2


{-| 軸テキスト/目盛り線の共通スタイル. 小型・控えめなグレーで, 目盛り線も細く付ける.
ラップ軸・順位軸など軸を持つチャートで共有する.
-}
axisStyle : Css.Style
axisStyle =
    descendants
        [ Css.Global.typeSelector "text"
            [ Css.fill (Css.hsl 0 0 0.7)
            , Css.fontSize (Css.px 9)
            ]
        , each
            [ Css.Global.typeSelector "line"
            , Css.Global.typeSelector "path"
            ]
            [ Css.Extra.strokeWidth 1
            , Css.property "stroke" "oklch(0.5 0 0 / 0.7)"
            ]
        ]


{-| ラップ番号の縦グリッド線(5周ごと). チャート上下のプロット領域いっぱいに引く.
-}
lapGridLines : Dimensions -> Scale.ContinuousScale Float -> ( Int, Int ) -> Svg msg
lapGridLines { height, padding } xScale ( minLap, maxLap ) =
    let
        gridLaps =
            List.range minLap maxLap |> List.filter (\l -> modBy 5 l == 0)

        top =
            padding.top

        bottom =
            height - padding.bottom
    in
    g [] <|
        List.map
            (\lap ->
                let
                    x =
                        toFloat lap |> Scale.convert xScale
                in
                line
                    [ SvgAttr.x1 (String.fromFloat x)
                    , SvgAttr.x2 (String.fromFloat x)
                    , SvgAttr.y1 (String.fromFloat top)
                    , SvgAttr.y2 (String.fromFloat bottom)
                    , SvgAttr.css
                        [ Css.property "stroke" "oklch(0.5 0 0 / 0.3)"
                        , Css.Extra.strokeWidth 1
                        ]
                    ]
                    []
            )
            gridLaps


{-| ラップ番号のX軸(下端). 毎ラップに目盛りを置き, ラベルは5周ごとに付ける.
-}
lapAxis : Dimensions -> Scale.ContinuousScale Float -> ( Int, Int ) -> Svg msg
lapAxis { height, padding } xScale ( minLap, maxLap ) =
    let
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
                    xScale
    in
    g
        [ SvgAttr.css [ axisStyle ]
        , transform [ Translate 0 (height - padding.bottom) ]
        ]
        [ axis ]


{-| Y軸(左端)の共通ラッパ. 目盛り値・整形(`Axis.Attribute`)はチャート固有なので
呼び出し側が渡し, スタイルと左パディングへの平行移動だけを共通化する.
-}
yAxis : Dimensions -> List (Axis.Attribute Float) -> Scale.ContinuousScale Float -> Svg msg
yAxis { padding } attributes yScale =
    g
        [ SvgAttr.css [ axisStyle ]
        , transform [ Translate padding.left 0 ]
        ]
        [ fromUnstyled (Axis.left attributes yScale) ]


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
