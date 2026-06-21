module Motorsport.Widget.Sparkline exposing
    ( CarLine, LinePoint, PlottedCar
    , carLine, groupReferenceByLap, gapPoints
    , consolidated, rivalStrip
    , gapSparkline, gapChartView
    )

{-| ラップ系スパークラインの共有プリミティブ. ラップ列の切り出し(`carLine`),
ラップ番号ごとのグループ基準(`groupReferenceByLap`)と相対ギャップ点列(`gapPoints`)を
提供する. ギャップ系チャートは縦軸計算・ゼロ基準線・折れ線描画をまとめた共通レンダラ
`gapChartView` を使う. 各チャートの寸法は [`Dimensions`](Motorsport-Chart-Common)
プリセット(`consolidated` / `rivalStrip`)として1か所に集約する. ラップ列の窓
([`LapWindow`](Motorsport-Chart-Common))・強調の有無([`Emphasis`](Motorsport-Chart-Common))・
外れ値処理([`iqrFences`](Motorsport-Chart-Common)等)は共有の `Motorsport.Chart.Common` を参照する.

@docs CarLine, LinePoint, PlottedCar
@docs carLine, groupReferenceByLap, gapPoints
@docs consolidated, rivalStrip
@docs gapSparkline, gapChartView

-}

import Css
import Dict exposing (Dict)
import Html.Styled exposing (Html, text)
import Motorsport.Chart.Common exposing (Dimensions, Emphasis(..), LapWindow(..), Scales, iqrFences, renderLine, svg)
import Motorsport.Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
import Scale
import Svg.Styled exposing (Svg, line)
import Svg.Styled.Attributes as SvgAttr


{-| スパークライン1本分のデータ(色・強調の有無・ラップ列).
-}
type alias CarLine =
    { color : Css.Color
    , emphasis : Emphasis
    , laps : List Lap
    }


{-| スパークライン上の1点. `value` は縦軸に取る整数量(ラップタイムや相対ギャップなど).
-}
type alias LinePoint =
    { lap : Int
    , value : Int
    }


{-| 描画1単位. スパークライン1本分のデータ(`car`)と, その縦軸へ投影した点列(`points`)を
組にする. `gapChartView` / `sparkCarLine` が受け取り, `gapSparkline` 等が組み立てる.
-}
type alias PlottedCar =
    { car : CarLine
    , points : List LinePoint
    }


{-| スパークライン1本分のデータ(色・強調・ラップ列)を組み立てる. ラップ列の窓は
`LapWindow` で, 強調の有無は `Emphasis` で指定する.
-}
carLine : Standings -> LapWindow -> Emphasis -> StandingsEntry -> CarLine
carLine standings window emphasis entry =
    let
        history =
            Standings.getCarHistory entry.metadata.carNumber standings
    in
    { color = Manufacturer.toColorWithFallback entry.metadata
    , emphasis = emphasis
    , laps =
        case window of
            Recent currentLap ->
                Standings.getRecentLaps { count = 20, currentLap = currentLap } history

            Range ( minLap, maxLap ) ->
                history |> List.filter (\lap -> minLap <= lap.lap && lap.lap <= maxLap)
    }


{-| 複数車の相対ギャップ推移を1枚に重ねて表示する. 与えられた車のグループ平均(非ピット
ラップの累積タイム平均)を基準=0ライン(点線)とし, 各車の `累積タイム − グループ平均` を
縦軸に取る. 基準より速い(累積小=先行)を上, 遅い(累積大=後退)を下に置くため, 線の上下動が
そのまま相対ペースの優劣になる.

絶対ラップタイムと違い, グループ平均を引くことで近接した同士のペース差が拡大されて
読みやすくなる. 縦軸はピット等の外れ値(両側 IQR)を除いた帯で張り, 外れ値は枠外へ
クリップする.

-}
gapSparkline : ( Int, Int ) -> Standings -> List StandingsEntry -> Html msg
gapSparkline ( minLap, maxLap ) standings entries =
    let
        carLines =
            entries |> List.map (carLine standings (Range ( minLap, maxLap )) Focused)

        referenceByLap =
            groupReferenceByLap carLines

        carsWithGaps =
            carLines |> List.map (\car -> { car = car, points = gapPoints referenceByLap car.laps })
    in
    if Dict.isEmpty referenceByLap then
        text ""

    else
        gapChartView consolidated
            ( toFloat minLap, toFloat (max maxLap (minLap + 1)) )
            carsWithGaps


{-| ラップ番号ごとのグループ基準 `referenceByLap` と各車のラップ列から, 相対ギャップ
点列(`累積タイム − 基準`)を組み立てる. 基準を持たないラップは点を作らず除外する.
-}
gapPoints : Dict Int Int -> List Lap -> List LinePoint
gapPoints referenceByLap laps =
    laps
        |> List.filterMap
            (\lap ->
                Dict.get lap.lap referenceByLap
                    |> Maybe.map (\ref -> { lap = lap.lap, value = lap.elapsed - ref })
            )


{-| 複数車の相対ギャップ点列を1枚に重ねて描く共通レンダラ. 縦軸は 0(グループ平均ペース)を
必ず含め, ピット等の外れ値(両側 IQR)を除いた帯で張って外れ値は枠外へクリップする. 基準より
速い(累積小=先行)を上, 遅い(累積大=後退)を下に置き, 0 ラインを破線で示す. 寸法とX軸範囲は
呼び出し側が `Dimensions` プリセットと `( minX, maxX )` で与える(統合チャートとカード内で
寸法だけが異なる).
-}
gapChartView :
    Dimensions
    -> ( Float, Float )
    -> List PlottedCar
    -> Html msg
gapChartView { width, height, padding } ( minX, maxX ) carsWithGaps =
    let
        allGaps =
            carsWithGaps |> List.concatMap (.points >> List.map .value)

        fences =
            iqrFences (List.sort allGaps)

        inBand gap =
            case fences of
                Just { lower, upper } ->
                    lower <= gap && gap <= upper

                Nothing ->
                    True

        bandGaps =
            allGaps |> List.filter inBand

        -- 0(グループ平均ペース)を必ず含めてレンジを張る.
        minGap =
            List.minimum (0 :: List.map toFloat bandGaps) |> Maybe.withDefault 0

        maxGap =
            List.maximum (0 :: List.map toFloat bandGaps) |> Maybe.withDefault 1 |> (\m -> max m (minGap + 1))

        yPad =
            (maxGap - minGap) * 0.15 + 50

        scales =
            { xScale = Scale.linear ( padding.left, width - padding.right ) ( minX, maxX )

            -- 基準より速い(累積小=先行)を上, 遅い(累積大=後退)を下に置く.
            , yScale = Scale.linear ( padding.top, height - padding.bottom ) ( minGap - yPad, maxGap + yPad )
            }
    in
    svg { width = width, height = height }
        (zeroReferenceLine { x1 = padding.left, x2 = width - padding.right, y = Scale.convert scales.yScale 0 }
            :: List.map (gapLine scales) carsWithGaps
        )


{-| `PlottedCar` を共通レンダラ `renderLine` の入力へ変換して1本描く. 縦軸量は相対ギャップ
(`累積タイム − グループ平均`).
-}
gapLine : Scales -> PlottedCar -> Svg msg
gapLine scales { car, points } =
    renderLine scales
        { color = car.color
        , emphasis = car.emphasis
        , points = points |> List.map (\p -> ( p.lap, p.value ))
        }


{-| グループ平均=0 を示す水平の破線.
-}
zeroReferenceLine : { x1 : Float, x2 : Float, y : Float } -> Svg msg
zeroReferenceLine { x1, x2, y } =
    line
        [ SvgAttr.x1 (String.fromFloat x1)
        , SvgAttr.x2 (String.fromFloat x2)
        , SvgAttr.y1 (String.fromFloat y)
        , SvgAttr.y2 (String.fromFloat y)
        , SvgAttr.stroke "hsl(0 0% 100% / 0.35)"
        , SvgAttr.strokeWidth "1"
        , SvgAttr.strokeDasharray "2 2"
        ]
        []


{-| 基準母集団の非ピットラップ(pitTime なし)だけを集め, ラップ番号ごとに累積タイムを
平均した基準を返す. ピットラップを除くことで基準が跳ねるのを防ぐ.
そのラップに非ピットラップを持つ車だけが平均に寄与する.
-}
groupReferenceByLap : List CarLine -> Dict Int Int
groupReferenceByLap carLines =
    carLines
        |> List.concatMap .laps
        |> List.filter (\lap -> lap.pitTime == Nothing)
        |> List.foldl
            (\lap ->
                Dict.update lap.lap
                    (\existing ->
                        case existing of
                            Just ( sum, count ) ->
                                Just ( sum + lap.elapsed, count + 1 )

                            Nothing ->
                                Just ( lap.elapsed, 1 )
                    )
            )
            Dict.empty
        |> Dict.map (\_ ( sum, count ) -> sum // count)


{-| 全幅で描く統合チャート(ギャップ)の寸法. 横長アスペクトにして, 幅100%へ伸ばした
ときの実高さ(幅 × 高さ/幅)を抑える.
-}
consolidated : Dimensions
consolidated =
    { width = 700, height = 80, padding = { top = 4, right = 3, bottom = 4, left = 3 } }


{-| カード内に収める前後ライバル比較(ギャップ)の寸法. 狭幅・低背に取る.
-}
rivalStrip : Dimensions
rivalStrip =
    { width = 200, height = 36, padding = { top = 4, right = 3, bottom = 4, left = 3 } }
