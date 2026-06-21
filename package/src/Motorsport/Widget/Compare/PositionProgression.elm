module Motorsport.Widget.Compare.PositionProgression exposing (lapRange, view)

import Axis exposing (tickFormat, tickSizeInner, tickSizeOuter, ticks)
import Css exposing (Color)
import Html.Styled exposing (Html)
import List.Extra
import Motorsport.Chart.Common exposing (Dimensions, Emphasis(..), Scales, lapAxis, lapGridLines, renderLine, svg, yAxis)
import Motorsport.Class exposing (Class)
import Motorsport.Clock as Clock
import Motorsport.Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)
import Motorsport.Widget as Widget
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg)


view : { width : Float, height : Float } -> Clock.Model -> Standings -> { class : Class, highlighted : List String } -> Html msg
view size clock standings target =
    case buildClassProgressionData clock standings target of
        Ok series ->
            positionProgressionChart size series

        Err message ->
            Widget.emptyState message


{-| ポジション履歴チャートが現在描いているラップ番号の範囲 `(minLap, maxLap)`.
スパークラインを同じ範囲(X軸)で描くために共有する. 表示対象が無いときは `Nothing`.
チャート本体と同じ閾値(直近3時間相当)・同じポイント抽出条件で算出する.
-}
lapRange : Clock.Model -> Standings -> Class -> Maybe ( Int, Int )
lapRange clock standings class =
    let
        lapNumbers =
            classPositionPoints clock standings class
                |> List.concatMap (Tuple.second >> List.map .lapNumber)
    in
    Maybe.map2 Tuple.pair (List.minimum lapNumbers) (List.maximum lapNumbers)


classCarsOf : Standings -> Class -> List StandingsEntry
classCarsOf standings class =
    Standings.toClassList standings
        |> List.Extra.find (\( class_, _ ) -> class_ == class)
        |> Maybe.map Tuple.second
        |> Maybe.withDefault []


{-| クラス内各車の「閾値以降の position points」を組み, 2点以上ある車だけを残す.
チャート本体と lapRange の X 軸を揃えるため, ポイント抽出条件をここに一本化する.
-}
classPositionPoints : Clock.Model -> Standings -> Class -> List ( StandingsEntry, List PositionPoint )
classPositionPoints clock standings class =
    let
        lapThreshold =
            calculateLapThreshold clock standings
    in
    classCarsOf standings class
        |> List.map (\item -> ( item, buildPositionPoints lapThreshold (Standings.getCarHistory item.metadata.carNumber standings) ))
        |> List.filter (\( _, points ) -> List.length points >= 2)


buildClassProgressionData : Clock.Model -> Standings -> { class : Class, highlighted : List String } -> Result String (List PositionSeries)
buildClassProgressionData clock standings { class, highlighted } =
    let
        series =
            classPositionPoints clock standings class
                |> List.map
                    (\( item, points ) ->
                        { points = points
                        , color = Manufacturer.toColorWithFallback item.metadata
                        , carNumber = item.metadata.carNumber
                        , emphasis =
                            if List.member item.metadata.carNumber highlighted then
                                Focused

                            else
                                Muted
                        }
                    )
    in
    if List.isEmpty series then
        Err "Lap chart will appear as more laps are completed."

    else
        Ok series


type alias PositionPoint =
    { lapNumber : Int
    , position : Int
    }


type alias PositionSeries =
    { points : List PositionPoint
    , color : Color
    , carNumber : String
    , emphasis : Emphasis
    }


{-| 点列が占めるラップ番号の範囲 `(minLap, maxLap)`. 空のときは `(1, 1)`.
-}
lapExtent : List PositionPoint -> ( Int, Int )
lapExtent positions =
    let
        laps =
            positions |> List.map .lapNumber
    in
    ( List.minimum laps |> Maybe.withDefault 1
    , List.maximum laps |> Maybe.withDefault 1
    )


positionHistoryWindowMillis : Int
positionHistoryWindowMillis =
    3 * 60 * 60 * 1000


calculateLapThreshold : Clock.Model -> Standings -> Int
calculateLapThreshold clock standings =
    let
        currentRaceTime =
            Clock.getElapsed clock

        timeThreshold =
            max 0 (currentRaceTime - positionHistoryWindowMillis)
    in
    Standings.leader standings
        |> Maybe.map (\l -> Standings.getCarHistory l.metadata.carNumber standings)
        |> Maybe.andThen (List.Extra.find (\lap -> lap.elapsed >= timeThreshold))
        |> Maybe.map .lap
        |> Maybe.withDefault 1


positionProgressionChart : { width : Float, height : Float } -> List PositionSeries -> Html msg
positionProgressionChart size series =
    let
        -- 軸ラベルのために左・下を厚めに取る非対称パディング.
        dimensions =
            { width = size.width
            , height = size.height
            , padding = { top = 15, right = 25, bottom = 25, left = 25 }
            }

        allPoints =
            series |> List.concatMap .points

        lapRange_ =
            lapExtent allPoints

        scales =
            { xScale = xContinuousScale dimensions lapRange_
            , yScale = yContinuousScale dimensions allPoints
            }
    in
    svg size
        ([ lapGridLines dimensions scales.xScale lapRange_
         , lapAxis dimensions scales.xScale lapRange_
         , positionAxis dimensions scales.yScale
         ]
            ++ List.map (positionLine scales) series
        )


buildPositionPoints : Int -> List Lap -> List PositionPoint
buildPositionPoints lapThreshold history =
    history
        |> List.filter (\lap -> lap.lap >= lapThreshold)
        |> List.filterMap
            (\lap ->
                lap.position |> Maybe.map (\pos -> { lapNumber = lap.lap, position = pos })
            )


xContinuousScale : Dimensions -> ( Int, Int ) -> ContinuousScale Float
xContinuousScale { width, padding } ( minLap, maxLap ) =
    Scale.linear ( padding.left, width - padding.right ) ( toFloat minLap, toFloat maxLap )


yContinuousScale : Dimensions -> List PositionPoint -> ContinuousScale Float
yContinuousScale { height, padding } positions =
    let
        allPositions =
            positions |> List.map .position

        ( minPos, maxPos ) =
            ( List.minimum allPositions |> Maybe.withDefault 1
            , List.maximum allPositions |> Maybe.withDefault 1
            )

        paddingY =
            max 1 ((maxPos - minPos) // 10)

        adjustedMin =
            max 0 (minPos - paddingY)

        adjustedMax =
            maxPos + paddingY
    in
    Scale.linear ( height - padding.bottom, padding.top ) ( toFloat adjustedMax, toFloat adjustedMin )


{-| Y軸(順位). ラベルは1位・5位・10位…と1-indexed で表示し, 共通ラッパ `yAxis` に
目盛り設定を渡して描く(スケールは0-indexed のためラベルで +1 する).
-}
positionAxis : Dimensions -> ContinuousScale Float -> Svg msg
positionAxis dimensions yScale =
    let
        ( domainMax, _ ) =
            Scale.domain yScale

        -- ラベルは1-indexed（1位、5位、10位...）、スケールは0-indexed
        labelPositions =
            1
                :: (List.range 1 ((round domainMax // 5) + 1) |> List.map (\i -> i * 5))
                |> List.filter (\v -> v - 1 <= round domainMax)

        tickValues_ =
            labelPositions |> List.map (\label -> toFloat (label - 1))
    in
    yAxis dimensions
        [ ticks tickValues_
        , tickSizeOuter 0
        , tickSizeInner 5
        , tickFormat (round >> (+) 1 >> String.fromInt)
        ]
        yScale


{-| `PositionSeries` を共通レンダラ `renderLine` の入力へ変換して1本描く. 縦軸量は順位.
-}
positionLine : Scales -> PositionSeries -> Svg msg
positionLine scales series =
    renderLine scales
        { color = series.color
        , emphasis = series.emphasis
        , label = series.carNumber
        , points = series.points |> List.map (\p -> ( p.lapNumber, p.position ))
        }
