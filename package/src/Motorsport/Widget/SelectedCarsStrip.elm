module Motorsport.Widget.SelectedCarsStrip exposing (view)

{-| その瞬間の総合上位数台について、直前ラップの確定値・ベスト・セクター成績を
横並びカードで表示する Widget. 選択操作なしでレース先頭の状況を俯瞰できる.

@docs view

-}

import Css exposing (backgroundColor, batch, before, num, opacity, property, qt)
import Dict
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


{-| 総合順位で隣接する前後のクルマ. 先頭/最後尾では一方が `Nothing` になる.
-}
type alias Neighbors =
    { ahead : Maybe StandingsEntry
    , behind : Maybe StandingsEntry
    }


{-| 同一クラス内の順位で `item` の前後に位置するクルマを取り出す.
総合順位リストはクラスでフィルタしても順序が保たれるため, そのままクラス内順位になる.
-}
findNeighbors : List StandingsEntry -> StandingsEntry -> Neighbors
findNeighbors allCars item =
    let
        classmates =
            allCars |> List.filter (\e -> e.metadata.class == item.metadata.class)
    in
    case List.Extra.findIndex (\e -> e.metadata.carNumber == item.metadata.carNumber) classmates of
        Just i ->
            { ahead = List.Extra.getAt (i - 1) classmates
            , behind = List.Extra.getAt (i + 1) classmates
            }

        Nothing ->
            { ahead = Nothing, behind = Nothing }


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
                , lapTimeSparkline
                    (Manufacturer.toColorWithFallback item.metadata)
                    (Standings.getCarHistory item.metadata.carNumber standings)
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


{-| 直近ラップの推移を小さな折れ線(スパークライン)で表示する.
線・ドットともにマニュファクチャラー色で統一する.

縦軸はレーシングラップの帯だけで張る. ピットイン・アウトラップなどの外れ値
(Q3 + 1.5×IQR 超)はドットを描かず, 縦軸の帯外(枠外)へはみ出させてクリップする.
折れ線自体は全ラップを繋いで描くため, 枠外へ伸びる線の角度から飛躍の大きさが読める.

-}
lapTimeSparkline : Css.Color -> List Lap -> Html msg
lapTimeSparkline color laps =
    let
        recent =
            recentLapsByLap laps
    in
    case recent of
        _ :: _ :: _ ->
            let
                lapNumbers =
                    recent |> List.map (.lap >> toFloat)

                times =
                    recent |> List.map .time

                sortedTimes =
                    List.sort times

                ( minX, maxX ) =
                    ( List.minimum lapNumbers |> Maybe.withDefault 0
                    , List.maximum lapNumbers |> Maybe.withDefault 1
                    )

                -- IQR による外れ値の上限フェンス. これを超えるラップ(主にピット系)は
                -- レーシング帯から外れているとみなし, 表示領域の外へ追いやる.
                upperFence =
                    Maybe.map2
                        (\q1 q3 -> q3 + round (1.5 * toFloat (q3 - q1)))
                        (quantile 0.25 sortedTimes)
                        (quantile 0.75 sortedTimes)
                        |> Maybe.withDefault (List.maximum sortedTimes |> Maybe.withDefault 0)

                bandTimes =
                    times |> List.filter (\t -> t <= upperFence)

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

                point lap =
                    ( Scale.convert xScale (toFloat lap.lap)
                    , Scale.convert yScale (toFloat lap.time)
                    )

                -- 折れ線は全ラップを繋いで描く. 外れ値は帯外(枠外)へ伸びてクリップされ,
                -- その線の角度で飛躍の大きさが読み取れる.
                linePath =
                    recent
                        |> List.map (point >> Just)
                        |> Shape.line Shape.linearCurve

                dot lap =
                    let
                        ( x, y ) =
                            point lap
                    in
                    circle
                        [ InPx.cx x
                        , InPx.cy y
                        , InPx.r 1.8
                        , SvgAttr.css [ Css.fill color ]
                        ]
                        []

                -- ドットは最新ラップ1点のみ. 線の終端=現在地を示す.
                lastDot =
                    recent
                        |> List.reverse
                        |> List.head
                        |> Maybe.map dot
                        |> Maybe.withDefault (text "")
            in
            svg
                [ SvgAttr.width "100%"
                , SvgAttr.css [ Css.property "display" "block" ]
                , viewBox 0 0 sparklineWidth sparklineHeight
                ]
                [ Path.element linePath
                    [ SvgAttr.stroke color.value
                    , SvgAttr.strokeWidth "1.5"
                    , SvgAttr.strokeOpacity "0.6"
                    , SvgAttr.fill "none"
                    ]
                , lastDot
                ]

        _ ->
            text ""



-- RIVAL GAP (sparkline)


{-| 前後のライバルとの位置関係を, 近傍3台(対象車＋前後車)のラップ平均を基準(中央の
0ライン=点線)にした相対ギャップの推移で表示する. 各ラップ番号での
`各車の累積タイム − グループ平均の累積タイム` をギャップとし, 対象車・前車・後車を
マニュファクチャラー色の折れ線で描く. 対象車だけは太線＋不透明で強調する.

基準を固定値(対象車そのもの)ではなくグループ平均にすることで, 対象車自身のペース
変動も0ラインからの離れ方として読み取れる. 線が上がれば(累積タイムが平均より小さい=)
相対的に速く先行, 下がれば相対的に遅く後退していることを表す. クラス先頭/最後尾で隣が
欠ける場合は, 存在する車だけで平均を取る.

-}
rivalGapSparkline : Standings -> Neighbors -> StandingsEntry -> Html msg
rivalGapSparkline standings neighbors item =
    let
        toCarLine isFocused entry =
            { color = Manufacturer.toColorWithFallback entry.metadata
            , isFocused = isFocused
            , laps = recentLapsByLap (Standings.getCarHistory entry.metadata.carNumber standings)
            }

        focusedLine =
            toCarLine True item

        -- フィールド順(前車 → 対象車 → 後車). 隣が欠ける場合は除外される.
        cars =
            List.filterMap identity
                [ Maybe.map (toCarLine False) neighbors.ahead
                , Just focusedLine
                , Maybe.map (toCarLine False) neighbors.behind
                ]

        -- 近傍グループの「ラップ番号 → 平均累積タイム」. そのラップに存在する車だけで平均する.
        referenceByLap =
            cars
                |> List.concatMap .laps
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

        gapSeries laps =
            laps
                |> List.filterMap
                    (\lap ->
                        Dict.get lap.lap referenceByLap
                            |> Maybe.map (\ref -> { lap = lap.lap, gap = lap.elapsed - ref })
                    )

        focusedLapNumbers =
            focusedLine.laps |> List.map (.lap >> toFloat)

        allGaps =
            cars |> List.concatMap (.laps >> gapSeries >> List.map (.gap >> toFloat))
    in
    case ( focusedLapNumbers, cars ) of
        ( _ :: _ :: _, _ :: _ :: _ ) ->
            let
                ( minX, maxX ) =
                    ( List.minimum focusedLapNumbers |> Maybe.withDefault 0
                    , List.maximum focusedLapNumbers |> Maybe.withDefault 1
                    )

                -- 0(グループ平均)を必ず含めてレンジを張る.
                minGap =
                    List.minimum (0 :: allGaps) |> Maybe.withDefault 0

                maxGap =
                    List.maximum (0 :: allGaps) |> Maybe.withDefault 1 |> (\m -> max m (minGap + 1))

                yPad =
                    (maxGap - minGap) * 0.15 + 200

                xScale =
                    Scale.linear ( sparklinePadX, sparklineWidth - sparklinePadX ) ( minX, maxX )

                -- 平均より速い(累積小=先行)を上, 遅い(累積大=後退)を下に置く.
                yScale =
                    Scale.linear ( sparklinePadY, rivalSparkHeight - sparklinePadY ) ( minGap - yPad, maxGap + yPad )

                zeroY =
                    Scale.convert yScale 0

                carLine car =
                    let
                        dataPoints =
                            gapSeries car.laps
                                |> List.filter (\{ lap } -> minX <= toFloat lap && toFloat lap <= maxX)
                                |> List.map
                                    (\{ lap, gap } ->
                                        Just
                                            ( Scale.convert xScale (toFloat lap)
                                            , Scale.convert yScale (toFloat gap)
                                            )
                                    )

                        lastDot =
                            dataPoints
                                |> List.filterMap identity
                                |> List.Extra.last
                                |> Maybe.map
                                    (\( x, y ) ->
                                        circle
                                            [ InPx.cx x
                                            , InPx.cy y
                                            , InPx.r
                                                (if car.isFocused then
                                                    2.2

                                                 else
                                                    1.8
                                                )
                                            , SvgAttr.css [ Css.fill car.color ]
                                            ]
                                            []
                                    )
                                |> Maybe.withDefault (text "")
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
                    :: List.map carLine cars
                )

        _ ->
            text ""


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
