module Motorsport.Widget.SelectedCarsStrip exposing (view)

{-| その瞬間の総合上位数台について、直前ラップの確定値・ベスト・セクター成績を
横並びカードで表示する Widget. 選択操作なしでレース先頭の状況を俯瞰できる.

@docs view

-}

import Css exposing (backgroundColor, batch, before, num, opacity, property, qt)
import Dict exposing (Dict)
import Html.Styled exposing (Html, button, div, img, text)
import Html.Styled.Attributes as Attributes exposing (class, css, src)
import Html.Styled.Events exposing (onClick)
import List.Extra
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Car as Car exposing (Status(..))
import Motorsport.Class as Class
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap
import Motorsport.Lap exposing (Lap)
import Motorsport.Lap.Performance as Performance exposing (performanceLevel)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Sector exposing (Sector(..))
import Motorsport.Standings as Standings exposing (SectorProgress, Standings, StandingsEntry)
import Path.Styled as Path
import Scale
import Shape
import Svg.Styled exposing (Svg, circle, g, svg)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes exposing (viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx


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


{-| rivalGapSparkline 用の1台分のデータ(色・対象車フラグ・直近ラップ列).
-}
type alias CarLine =
    { color : Css.Color
    , isFocused : Bool
    , laps : List Lap
    }


{-| スパークライン上の1点. `value` は縦軸に取る整数量で,
ラップタイム(lapTimeSparkline)や基準からの相対ギャップ(rivalGapSparkline)を表す.
-}
type alias LinePoint =
    { lap : Int
    , value : Int
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


{-| スパークライン1本分のデータ(色・対象車フラグ・直近ラップ列)を組み立てる.
-}
toCarLine : Standings -> Bool -> StandingsEntry -> CarLine
toCarLine standings isFocused entry =
    { color = Manufacturer.toColorWithFallback entry.metadata
    , isFocused = isFocused
    , laps = recentLapsByLap (Standings.getCarHistory entry.metadata.carNumber standings)
    }


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
                , div
                    [ css
                        [ property "display" "grid"
                        , property "grid-template-columns" "auto 1fr 1fr"
                        , property "align-items" "center"
                        , property "column-gap" "8px"
                        ]
                    ]
                    [ currentSectorPie analysis item
                    , currentLapBlock analysis item
                    , lastLapBlock item
                    ]
                , lapTimeSparkline standings item
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
        [ carNumberBadge item
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


manufacturerLogo : Manufacturer.Manufacturer -> Html msg
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


{-| Current ラップ: 進行中のラップタイムと, 各セクターの進捗(進行中)/成績(確定)を
横3分割のバーで表示する. Retired や計測前は "-" を出す.
-}
currentLapBlock : Analysis -> StandingsEntry -> Html msg
currentLapBlock analysis item =
    lapBlock "Current" (currentLapTimeCell analysis item)


{-| Last ラップ: 確定したラップタイム・対ベスト差・セクター成績を表示する.
-}
lastLapBlock : StandingsEntry -> Html msg
lastLapBlock item =
    lapBlock "Last" (lastLapTimeCell item)


{-| ラップ1段分の共通レイアウト. 上段にラベル・タイム・末尾(差分など), 下段にセクターバー.
-}
lapBlock : String -> Html msg -> Html msg
lapBlock label timeCell =
    div
        [ css
            [ property "display" "grid"
            , property "place-items" "center"
            , property "row-gap" "1px"
            ]
        ]
        [ labelText label
        , timeCell
        ]


currentLapTimeCell : Analysis -> StandingsEntry -> Html msg
currentLapTimeCell analysis item =
    let
        colorStyle =
            case item.currentLapBest of
                Just best ->
                    performanceLevel
                        { time = item.currentLapElapsed, personalBest = best, fastest = analysis.fastestLapTime }
                        |> applyPerformanceColor

                Nothing ->
                    batch []
    in
    div
        [ css
            [ property "font-size" "13px"
            , property "font-variant-numeric" "tabular-nums"
            , property "text-align" "right"
            , colorStyle
            ]
        ]
        [ text
            (if Car.hasRetired item.status then
                "-"

             else
                Duration.toString item.currentLapElapsed
            )
        ]


lastLapTimeCell : StandingsEntry -> Html msg
lastLapTimeCell item =
    div
        [ css
            [ property "font-size" "13px"
            , property "font-variant-numeric" "tabular-nums"
            , property "text-align" "right"
            , case item.lastLap of
                Just { performance } ->
                    applyPerformanceColor performance

                Nothing ->
                    batch []
            ]
        ]
        [ text (item.lastLap |> Maybe.map (.time >> Duration.toString) |> Maybe.withDefault "-") ]


applyPerformanceColor : Performance.PerformanceLevel -> Css.Style
applyPerformanceColor performance =
    if Performance.isStandard performance then
        batch []

    else
        property "color" (Performance.toColorVariable performance)


{-| Current ラップのセクター成績を小さなドーナツ(3分割)で表示する.
進行中セクターは進捗率ぶんだけ白で, 確定済みセクターは成績色で塗る.
-}
currentSectorPie : Analysis -> StandingsEntry -> Html msg
currentSectorPie analysis item =
    case ( item.currentLapSectors, Car.hasRetired item.status ) of
        ( Just sectors, False ) ->
            let
                ( s1p, s2p, s3p ) =
                    sectorProgressTriplet item.sector
            in
            sectorPie
                [ currentSectorSlot { time = sectors.sector_1, personalBest = sectors.s1_best, fastest = analysis.sector_1_fastest, progress = s1p }
                , currentSectorSlot { time = sectors.sector_2, personalBest = sectors.s2_best, fastest = analysis.sector_2_fastest, progress = s2p }
                , currentSectorSlot { time = sectors.sector_3, personalBest = sectors.s3_best, fastest = analysis.sector_3_fastest, progress = s3p }
                ]

        _ ->
            emptyPie


sectorProgressTriplet : Maybe SectorProgress -> ( Float, Float, Float )
sectorProgressTriplet sectorProgress =
    case sectorProgress of
        Just { sector, progress } ->
            case sector of
                S1 ->
                    ( progress, 0, 0 )

                S2 ->
                    ( 100, progress, 0 )

                S3 ->
                    ( 100, 100, progress )

        Nothing ->
            ( 100, 100, 100 )


{-| 1セクター分のスロットを `(塗り色, 充填率0..1)` に変換する.
進行中(progress < 100)は白で進捗率ぶん, 確定済みは成績色で全周.
-}
currentSectorSlot : { time : Duration, personalBest : Duration, fastest : Duration, progress : Float } -> ( String, Float )
currentSectorSlot sector =
    if sector.progress < 100 then
        ( "oklch(1 0 0)", sector.progress / 100 )

    else
        ( performanceLevel { time = sector.time, personalBest = sector.personalBest, fastest = sector.fastest }
            |> Performance.toColorVariable
        , 1
        )


{-| 3スロットを受け取り, 各スロットを 120° のドーナツ扇形として描く.
各要素は `(塗り色, 充填率0..1)`. 充填率ぶんだけスロット先頭から塗り, 背後に薄いトラックを敷く.
-}
sectorPie : List ( String, Float ) -> Html msg
sectorPie slots =
    svg
        [ SvgAttr.width (String.fromFloat pieSize ++ "px")
        , SvgAttr.height (String.fromFloat pieSize ++ "px")
        , SvgAttr.css [ Css.property "display" "block" ]
        , viewBox 0 0 pieSize pieSize
        ]
        [ g
            [ SvgAttr.transform
                ("translate(" ++ String.fromFloat (pieSize / 2) ++ " " ++ String.fromFloat (pieSize / 2) ++ ")")
            ]
            (slots |> List.indexedMap sectorSlot |> List.concat)
        ]


emptyPie : Html msg
emptyPie =
    sectorPie [ ( "transparent", 0 ), ( "transparent", 0 ), ( "transparent", 0 ) ]


sectorSlot : Int -> ( String, Float ) -> List (Svg msg)
sectorSlot index ( color, fraction ) =
    let
        slot =
            2 * pi / 3

        arc fillFraction =
            Shape.arc
                { innerRadius = pieInner
                , outerRadius = pieOuter
                , cornerRadius = 1
                , startAngle = toFloat index * slot + pieGap / 2
                , endAngle = toFloat index * slot + pieGap / 2 + (slot - pieGap) * fillFraction
                , padAngle = 0
                , padRadius = 0
                }

        track =
            Path.element (arc 1) [ SvgAttr.fill "hsl(0 0% 100% / 0.12)" ]
    in
    if fraction <= 0 then
        [ track ]

    else
        [ track, Path.element (arc fraction) [ SvgAttr.fill color ] ]


pieSize : Float
pieSize =
    30


pieOuter : Float
pieOuter =
    13


pieInner : Float
pieInner =
    6.5


{-| スロット間の隙間(ラジアン).
-}
pieGap : Float
pieGap =
    0.12



-- LAP TIME PROGRESSION (sparkline)


{-| 対象車の直近ラップタイムの推移を小さな折れ線(スパークライン)で表示する.
線・ドットともにマニュファクチャラー色で統一する. ライバルの重ね描きは情報過多に
なるため行わない(前後関係は rivalGapSparkline が受け持つ).

縦軸はレーシングラップの帯だけで張る. ピットイン・アウトラップなどの外れ値
(Q3 + 1.5×IQR 超)はドットを描かず, 縦軸の帯外(枠外)へはみ出させてクリップする.
折れ線自体は全ラップを繋いで描くため, 枠外へ伸びる線の角度から飛躍の大きさが読める.

-}
lapTimeSparkline : Standings -> StandingsEntry -> Html msg
lapTimeSparkline standings item =
    let
        focusedLine =
            toCarLine standings True item

        focusedLapNumbers =
            focusedLine.laps |> List.map (.lap >> toFloat)

        carsWithPoints =
            [ { car = focusedLine
              , points = focusedLine.laps |> List.map (\lap -> { lap = lap.lap, value = lap.time })
              }
            ]

        allTimes =
            carsWithPoints |> List.concatMap (.points >> List.map .value)

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
    case focusedLapNumbers of
        _ :: _ :: _ ->
            let
                ( minX, maxX ) =
                    ( List.minimum focusedLapNumbers |> Maybe.withDefault 0
                    , List.maximum focusedLapNumbers |> Maybe.withDefault 1
                    )

                minY =
                    List.minimum bandTimes |> Maybe.withDefault 0 |> toFloat

                maxY =
                    List.maximum bandTimes |> Maybe.withDefault 1 |> toFloat |> (\m -> max m (minY + 1))

                yPad =
                    (maxY - minY) * 0.1 + 1

                xScale =
                    Scale.linear ( sparklinePadX, sparklineWidth - sparklinePadX ) ( minX, maxX )

                yScale =
                    Scale.linear ( sparklineHeight - sparklinePadY, sparklinePadY ) ( minY - yPad, maxY + yPad )

                cfg =
                    { xScale = xScale, yScale = yScale, minX = minX, maxX = maxX, inBand = inBand }
            in
            svg
                [ SvgAttr.width "100%"
                , SvgAttr.css [ Css.property "display" "block" ]
                , viewBox 0 0 sparklineWidth sparklineHeight
                ]
                (List.map (sparkCarLine cfg) carsWithPoints)

        _ ->
            text ""



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

-}
rivalGapSparkline : Standings -> Neighbors -> StandingsEntry -> Html msg
rivalGapSparkline standings neighbors item =
    let
        -- 各車の CarLine(全履歴ソートを含む)は一度だけ算出して使い回す.
        aheadLines =
            neighbors.ahead |> List.map (toCarLine standings False)

        behindLines =
            neighbors.behind |> List.map (toCarLine standings False)

        focusedLine =
            toCarLine standings True item

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
            groupReferenceByLap referenceCars

        gapSeries laps =
            laps
                |> List.filterMap
                    (\lap ->
                        Dict.get lap.lap referenceByLap
                            |> Maybe.map (\ref -> { lap = lap.lap, value = lap.elapsed - ref })
                    )

        -- 各車のギャップ点列を一度だけ算出して保持する(縦軸計算と描画で共用).
        carsWithGaps =
            cars |> List.map (\car -> { car = car, points = gapSeries car.laps })

        focusedLapNumbers =
            focusedLine.laps |> List.map (.lap >> toFloat)

        allGaps =
            carsWithGaps |> List.concatMap (.points >> List.map .value)

        -- ピット等の外れ値(両側)を IQR で除いた「通常変動の帯」. これで縦軸を張り,
        -- 外れ値の点は枠外へはみ出してクリップさせる(線は繋がるので飛躍は角度で読める).
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
    case ( focusedLapNumbers, rivalLines, Dict.isEmpty referenceByLap ) of
        ( _ :: _ :: _, _ :: _, False ) ->
            let
                ( minX, maxX ) =
                    ( List.minimum focusedLapNumbers |> Maybe.withDefault 0
                    , List.maximum focusedLapNumbers |> Maybe.withDefault 1
                    )

                -- 0(ライバル平均ペース)を必ず含めてレンジを張る.
                minGap =
                    List.minimum (0 :: List.map toFloat bandGaps) |> Maybe.withDefault 0

                maxGap =
                    List.maximum (0 :: List.map toFloat bandGaps) |> Maybe.withDefault 1 |> (\m -> max m (minGap + 1))

                yPad =
                    (maxGap - minGap) * 0.15 + 50

                xScale =
                    Scale.linear ( sparklinePadX, sparklineWidth - sparklinePadX ) ( minX, maxX )

                -- 基準より速い(累積小=先行)を上, 遅い(累積大=後退)を下に置く.
                yScale =
                    Scale.linear ( sparklinePadY, rivalSparkHeight - sparklinePadY ) ( minGap - yPad, maxGap + yPad )

                zeroY =
                    Scale.convert yScale 0

                cfg =
                    { xScale = xScale, yScale = yScale, minX = minX, maxX = maxX, inBand = inBand }
            in
            svg
                [ SvgAttr.width "100%"
                , SvgAttr.css [ Css.property "display" "block" ]
                , viewBox 0 0 sparklineWidth rivalSparkHeight
                ]
                (Svg.Styled.line
                    [ SvgAttr.x1 (String.fromFloat sparklinePadX)
                    , SvgAttr.x2 (String.fromFloat (sparklineWidth - sparklinePadX))
                    , SvgAttr.y1 (String.fromFloat zeroY)
                    , SvgAttr.y2 (String.fromFloat zeroY)
                    , SvgAttr.stroke "hsl(0 0% 100% / 0.35)"
                    , SvgAttr.strokeWidth "1"
                    , SvgAttr.strokeDasharray "2 2"
                    ]
                    []
                    :: List.map (sparkCarLine cfg) carsWithGaps
                )

        _ ->
            text ""


{-| 基準母集団(最大5台)の非ピットラップ(pitTime なし)だけを集め, ラップ番号ごとに
累積タイムを平均した基準を返す. ピットラップを除くことで基準が跳ねるのを防ぐ.
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


{-| 1台分の折れ線＋終端ドットを描く. 縦軸の値は呼び出し側が `LinePoint` に詰めた
ラップタイムまたは相対ギャップ. 終端ドットは最終点が帯内のときだけ描き, 枠外の
ピットラップ上に浮くのを防ぐ. 対象車は太線＋不透明で強調する.
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


{-| ラップ履歴を昇順にそろえ, 直近20ラップだけを取り出す.
-}
recentLapsByLap : List Lap -> List Lap
recentLapsByLap laps =
    laps
        |> List.sortBy .lap
        |> List.reverse
        |> List.take 20
        |> List.reverse


rivalSparkHeight : Float
rivalSparkHeight =
    36


sparklineWidth : Float
sparklineWidth =
    200


sparklineHeight : Float
sparklineHeight =
    40


sparklinePadX : Float
sparklinePadX =
    3


sparklinePadY : Float
sparklinePadY =
    4


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


labelText : String -> Html msg
labelText label =
    div
        [ css
            [ property "font-size" "9px"
            , opacity (num 0.6)
            ]
        ]
        [ text label ]


formatDriverName : String -> String
formatDriverName fullName =
    case String.words fullName of
        first :: rest ->
            first :: (rest |> List.map String.toUpper) |> String.join " "

        [] ->
            fullName
