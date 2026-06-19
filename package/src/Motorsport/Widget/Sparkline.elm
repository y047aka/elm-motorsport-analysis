module Motorsport.Widget.Sparkline exposing
    ( CarLine, LinePoint
    , toCarLine, sparkCarLine, iqrFences, groupReferenceByLap
    , sparklineWidth, sparklinePadX, sparklinePadY
    , lapTimeSparkline, gapSparkline
    )

{-| ラップ系スパークラインの共有プリミティブ. 折れ線＋終端ドットの描画(`sparkCarLine`),
直近ラップ列の組み立て(`toCarLine`), IQR 外れ値フェンス(`iqrFences`)を提供し,
これらを使う具体的なスパークライン(`lapTimeSparkline` / `gapSparkline` や呼び出し側の
rivalGapSparkline)で共有する.

@docs CarLine, LinePoint
@docs toCarLine, sparkCarLine, iqrFences, groupReferenceByLap
@docs sparklineWidth, sparklinePadX, sparklinePadY
@docs lapTimeSparkline, gapSparkline

-}

import Css
import Dict exposing (Dict)
import Html.Styled exposing (Html, text)
import List.Extra
import Motorsport.Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
import Path.Styled as Path
import Scale
import Shape
import Svg.Styled exposing (Svg, circle, g, line, svg)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes exposing (viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx


{-| スパークライン1本分のデータ(色・対象車フラグ・直近ラップ列).
-}
type alias CarLine =
    { color : Css.Color
    , isFocused : Bool
    , laps : List Lap
    }


{-| スパークライン上の1点. `value` は縦軸に取る整数量(ラップタイムや相対ギャップなど).
-}
type alias LinePoint =
    { lap : Int
    , value : Int
    }


{-| スパークライン1本分のデータ(色・対象車フラグ・直近ラップ列)を組み立てる.
`currentLap` は対象車の現在ラップ. 全車をこのラップ起点の窓で切り出すことで,
リタイア済み・大きく遅れた隣接車の古いラップが基準平均に混入するのを防ぐ.
-}
toCarLine : Standings -> Int -> Bool -> StandingsEntry -> CarLine
toCarLine standings currentLap isFocused entry =
    { color = Manufacturer.toColorWithFallback entry.metadata
    , isFocused = isFocused
    , laps =
        Standings.getRecentLaps { count = 20, currentLap = currentLap }
            (Standings.getCarHistory entry.metadata.carNumber standings)
    }


{-| ラップ範囲 `(minLap, maxLap)` に収まる確定ラップだけで CarLine を組み立てる.
ポジション履歴と同じ範囲(X軸)でスパークラインを描くために使う. 全車を強調表示する.
-}
toCarLineInRange : Standings -> ( Int, Int ) -> StandingsEntry -> CarLine
toCarLineInRange standings ( minLap, maxLap ) entry =
    { color = Manufacturer.toColorWithFallback entry.metadata
    , isFocused = True
    , laps =
        Standings.getCarHistory entry.metadata.carNumber standings
            |> List.filter (\lap -> minLap <= lap.lap && lap.lap <= maxLap)
    }


{-| 1台分の直近ラップタイムの推移を折れ線(スパークライン)で表示する. 車両ごとに1枚ずつ
並べる用途. X軸は呼び出し側が渡すラップ範囲 `(minLap, maxLap)` に固定し(ポジション履歴と
同じ範囲), 複数車を横並びにしてもX軸が揃う. Y軸はその車自身のレーシング帯で張る.

縦軸はレーシングラップの帯だけで張る. ピットイン・アウトラップなどの外れ値
(Q3 + 1.5×IQR 超)はドットを描かず, 縦軸の帯外(枠外)へはみ出させてクリップする.
折れ線自体は全ラップを繋いで描くため, 枠外へ伸びる線の角度から飛躍の大きさが読める.

-}
lapTimeSparkline : ( Int, Int ) -> Standings -> StandingsEntry -> Html msg
lapTimeSparkline (( minLap, maxLap ) as range) standings entry =
    let
        car =
            toCarLineInRange standings range entry

        points =
            car.laps |> List.map (\lap -> { lap = lap.lap, value = lap.time })

        allTimes =
            points |> List.map .value

        -- IQR による外れ値の上限フェンス. これを超えるラップ(主にピット系)は
        -- レーシング帯から外れているとみなし, 表示領域の外へ追いやる.
        upperFence =
            iqrFences (List.sort allTimes)
                |> Maybe.map .upper
                |> Maybe.withDefault (List.maximum allTimes |> Maybe.withDefault 0)

        inBand t =
            t <= upperFence

        bandTimes =
            allTimes |> List.filter inBand
    in
    case points of
        _ :: _ :: _ ->
            let
                minX =
                    toFloat minLap

                maxX =
                    toFloat (max maxLap (minLap + 1))

                minY =
                    List.minimum bandTimes |> Maybe.withDefault 0 |> toFloat

                maxY =
                    List.maximum bandTimes |> Maybe.withDefault 1 |> toFloat |> (\m -> max m (minY + 1))

                yPad =
                    (maxY - minY) * 0.1 + 1

                xScale =
                    Scale.linear ( sparklinePadX, columnWidth - sparklinePadX ) ( minX, maxX )

                yScale =
                    Scale.linear ( columnHeight - sparklinePadY, sparklinePadY ) ( minY - yPad, maxY + yPad )

                cfg =
                    { xScale = xScale, yScale = yScale, minX = minX, maxX = maxX, inBand = inBand }
            in
            svg
                [ SvgAttr.width "100%"
                , SvgAttr.css [ Css.property "display" "block" ]
                , viewBox 0 0 columnWidth columnHeight
                ]
                [ sparkCarLine cfg { car = car, points = points } ]

        _ ->
            text ""


{-| 複数車の相対ギャップ推移を1枚に重ねて表示する. 与えられた車のグループ平均(非ピット
ラップの累積タイム平均)を基準=0ライン(点線)とし, 各車の `累積タイム − グループ平均` を
縦軸に取る. 基準より速い(累積小=先行)を上, 遅い(累積大=後退)を下に置くため, 線の上下動が
そのまま相対ペースの優劣になる.

絶対ラップタイム版(`lapTimeSparkline`)と違い, グループ平均を引くことで近接した同士の
ペース差が拡大されて読みやすくなる. 縦軸はピット等の外れ値(両側 IQR)を除いた帯で張り,
外れ値は枠外へクリップする.

-}
gapSparkline : ( Int, Int ) -> Standings -> List StandingsEntry -> Html msg
gapSparkline ( minLap, maxLap ) standings entries =
    let
        carLines =
            entries |> List.map (toCarLineInRange standings ( minLap, maxLap ))

        referenceByLap =
            groupReferenceByLap carLines

        gapSeries laps =
            laps
                |> List.filterMap
                    (\lap ->
                        Dict.get lap.lap referenceByLap
                            |> Maybe.map (\ref -> { lap = lap.lap, value = lap.elapsed - ref })
                    )

        carsWithGaps =
            carLines |> List.map (\car -> { car = car, points = gapSeries car.laps })

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
    in
    if Dict.isEmpty referenceByLap then
        text ""

    else
        let
            minX =
                toFloat minLap

            maxX =
                toFloat (max maxLap (minLap + 1))

            -- 0(グループ平均ペース)を必ず含めてレンジを張る.
            minGap =
                List.minimum (0 :: List.map toFloat bandGaps) |> Maybe.withDefault 0

            maxGap =
                List.maximum (0 :: List.map toFloat bandGaps) |> Maybe.withDefault 1 |> (\m -> max m (minGap + 1))

            yPad =
                (maxGap - minGap) * 0.15 + 50

            xScale =
                Scale.linear ( sparklinePadX, consolidatedWidth - sparklinePadX ) ( minX, maxX )

            -- 基準より速い(累積小=先行)を上, 遅い(累積大=後退)を下に置く.
            yScale =
                Scale.linear ( sparklinePadY, consolidatedHeight - sparklinePadY ) ( minGap - yPad, maxGap + yPad )

            zeroY =
                Scale.convert yScale 0

            cfg =
                { xScale = xScale, yScale = yScale, minX = minX, maxX = maxX, inBand = inBand }
        in
        svg
            [ SvgAttr.width "100%"
            , SvgAttr.css [ Css.property "display" "block" ]
            , viewBox 0 0 consolidatedWidth consolidatedHeight
            ]
            (line
                [ SvgAttr.x1 (String.fromFloat sparklinePadX)
                , SvgAttr.x2 (String.fromFloat (consolidatedWidth - sparklinePadX))
                , SvgAttr.y1 (String.fromFloat zeroY)
                , SvgAttr.y2 (String.fromFloat zeroY)
                , SvgAttr.stroke "hsl(0 0% 100% / 0.35)"
                , SvgAttr.strokeWidth "1"
                , SvgAttr.strokeDasharray "2 2"
                ]
                []
                :: List.map (sparkCarLine cfg) carsWithGaps
            )


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


{-| 1台分の折れ線＋終端ドットを描く. 縦軸の値は呼び出し側が `LinePoint` に詰める.
終端ドットは最終点が帯内のときだけ描き, 枠外のピットラップ上に浮くのを防ぐ.
対象車は太線＋不透明で強調する.
-}
sparkCarLine :
    { xScale : Scale.ContinuousScale Float
    , yScale : Scale.ContinuousScale Float
    , minX : Float
    , maxX : Float
    , inBand : Int -> Bool
    }
    -> { car : CarLine, points : List LinePoint }
    -> Svg msg
sparkCarLine { xScale, yScale, minX, maxX, inBand } { car, points } =
    let
        visible =
            points |> List.filter (\{ lap } -> minX <= toFloat lap && toFloat lap <= maxX)

        dataPoints =
            visible
                |> List.map
                    (\{ lap, value } ->
                        Just
                            ( Scale.convert xScale (toFloat lap)
                            , Scale.convert yScale (toFloat value)
                            )
                    )

        lastDot =
            case List.Extra.last visible of
                Just { lap, value } ->
                    if inBand value then
                        circle
                            [ InPx.cx (Scale.convert xScale (toFloat lap))
                            , InPx.cy (Scale.convert yScale (toFloat value))
                            , InPx.r
                                (if car.isFocused then
                                    2.2

                                 else
                                    1.8
                                )
                            , SvgAttr.css [ Css.fill car.color ]
                            ]
                            []

                    else
                        text ""

                Nothing ->
                    text ""
    in
    g []
        [ Path.element (Shape.line Shape.linearCurve dataPoints)
            [ SvgAttr.stroke car.color.value
            , SvgAttr.strokeWidth
                (if car.isFocused then
                    "2"

                 else
                    "1.5"
                )
            , SvgAttr.strokeOpacity
                (if car.isFocused then
                    "1"

                 else
                    "0.5"
                )
            , SvgAttr.fill "none"
            ]
        , lastDot
        ]


sparklineWidth : Float
sparklineWidth =
    200


sparklinePadX : Float
sparklinePadX =
    3


sparklinePadY : Float
sparklinePadY =
    4


{-| 全幅で描く統合チャート(ギャップ)の viewBox 寸法. 横長アスペクトにして, 幅100%へ
伸ばしたときの実高さ(幅 × 高さ/幅)を抑える.
-}
consolidatedWidth : Float
consolidatedWidth =
    700


consolidatedHeight : Float
consolidatedHeight =
    80


{-| 車両ごとに1枚並べる(3カラム)ラップタイムチャートの viewBox 寸法.
1カラム幅で描くため統合チャートより横幅を狭めに取る.
-}
columnWidth : Float
columnWidth =
    300


columnHeight : Float
columnHeight =
    40


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
