module Motorsport.Widget.CarStatus exposing (carNumberBadge, carNumberBadgeRow, sectorAndLaps)

{-| 1台分の「セクター進捗パイ + Current ラップ + Last ラップ」を横並びで描く共有部品.
SelectedCarsStrip と Compare の双方で同じ見た目を使うために切り出した.

@docs carNumberBadge, carNumberBadgeRow, sectorAndLaps

-}

import Css exposing (batch, num, opacity, property)
import Html.Styled exposing (Html, div, img, text)
import Html.Styled.Attributes exposing (alt, class, css, src)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Car as Car
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap.Performance as Performance exposing (performanceLevel)
import Motorsport.Manufacturer as Manufacturer exposing (Manufacturer)
import Motorsport.Sector exposing (Sector(..))
import Motorsport.Standings exposing (SectorProgress, StandingsEntry)
import Path.Styled as Path
import Shape
import Svg.Styled exposing (Svg, g, svg)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes exposing (viewBox)


{-| マニュファクチャラー色の小さな縦積みバッジ. ロゴ(上)と車番(下)を重ねる.
-}
carNumberBadge : StandingsEntry -> Html msg
carNumberBadge item =
    badge "flex flex-col items-center justify-center gap-1.5 p-1 rounded w-[35px]"
        [ manufacturerLogo
            [ property "max-width" "28px"
            , property "height" "16px"
            , property "object-fit" "contain"
            , property "opacity" "0.9"
            ]
            item.metadata.manufacturer
        , div [ class "text-xs font-bold leading-none" ]
            [ text item.metadata.carNumber ]
        ]
        item


{-| マニュファクチャラー色の横並びバッジ. ロゴ(左)と車番(右)を並べる.
-}
carNumberBadgeRow : StandingsEntry -> Html msg
carNumberBadgeRow item =
    badge "p-1 grid grid-cols-[20px_25px] gap-1 place-items-center rounded"
        [ manufacturerLogo
            [ property "height" "14px"
            , property "object-fit" "contain"
            ]
            item.metadata.manufacturer
        , div [ class "text-center leading-none text-xs font-bold" ]
            [ text item.metadata.carNumber ]
        ]
        item


{-| マニュファクチャラー色を背景に敷くバッジの外枠. 中身は呼び出し側が組み立てる.
-}
badge : String -> List (Html msg) -> StandingsEntry -> Html msg
badge containerClass children item =
    div
        [ class containerClass
        , css [ Css.backgroundColor (Manufacturer.toColor item.metadata.manufacturer) ]
        ]
        children


manufacturerLogo : List Css.Style -> Manufacturer -> Html msg
manufacturerLogo styles manufacturer =
    case Manufacturer.toLogoUrl manufacturer of
        Just url ->
            img [ src url, alt (Manufacturer.toString manufacturer), css styles ] []

        Nothing ->
            div [ css styles ] []


{-| セクター進捗パイ + Current ラップ + Last ラップを描く.
pie はセクター進捗(＝Current ラップ)を示すので Current と同じ列にまとめ,
左右 50/50 の2カラム(`pie + Current` | `Last`)でバランスよく並べる.
-}
sectorAndLaps : Analysis -> StandingsEntry -> Html msg
sectorAndLaps analysis item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "1fr 1fr"
            , property "place-items" "center"
            , property "column-gap" "8px"
            ]
        ]
        [ div
            [ css
                [ property "display" "grid"
                , property "width" "fit-content"
                , property "grid-template-columns" "auto auto"
                , property "align-items" "center"
                , property "column-gap" "8px"
                ]
            ]
            [ currentSectorPie analysis item
            , currentLapBlock analysis item
            ]
        , lastLapBlock item
        ]


{-| Current ラップ: 進行中のラップタイムと, 各セクターの進捗(進行中)/成績(確定)を表示する.
-}
currentLapBlock : Analysis -> StandingsEntry -> Html msg
currentLapBlock analysis item =
    lapBlock "Current" (currentLapTimeCell analysis item)


{-| Last ラップ: 確定したラップタイム・対ベスト差を表示する.
-}
lastLapBlock : StandingsEntry -> Html msg
lastLapBlock item =
    lapBlock "Last" (lastLapTimeCell item)


{-| ラップ1段分の共通レイアウト. 上段にラベル, 下段にタイム.
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


labelText : String -> Html msg
labelText label =
    div
        [ css
            [ property "font-size" "9px"
            , opacity (num 0.6)
            ]
        ]
        [ text label ]
