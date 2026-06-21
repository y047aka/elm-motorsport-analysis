module Motorsport.Chart.LapTimeDistribution exposing (Series, domainOf, maxDensityOf, view)

{-| 車両のラップタイムの分布をカーネル密度推定(KDE)のスムーズな曲線で可視化するチャート.
時系列スパークライン(推移)では読み取りにくい「ペースの安定度・典型ラップ・ばらつき」を
分布として示し, 複数車の比較を容易にする. elm-visualization の Peaks 例に倣い, 半透明の
塗り(area)＋実線(line)で密度を描き, 直近ラップ(`lastLap`)が分布上のどこに位置するかを
1点のマーカーで示す.

1台でも複数台でも同じ `view` で描く. 複数 Series を渡すと横軸(ラップタイム)を共有して重ね描く.

@docs Series, domainOf, maxDensityOf, view

-}

import Axis
import Css exposing (Style, property)
import Css.Global exposing (descendants, each, typeSelector)
import Html.Styled exposing (Html, text)
import Html.Styled.Attributes exposing (css)
import Motorsport.Chart.Common exposing (Emphasis)
import Motorsport.Duration as Duration
import Path.Styled as Path
import Scale exposing (ContinuousScale)
import Shape
import Statistics
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, svg, text_)
import Svg.Styled.Attributes as SvgAttr
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx
import TypedSvg.Types exposing (Transform(..))


{-| 分布チャート1本分のデータ. `times` は外れ値除去済みのレーシングラップタイム(ms),
`lastLap` は分布上に1点で示す直近ラップタイム(ms).
-}
type alias Series =
    { color : Css.Color
    , emphasis : Emphasis
    , times : List Int
    , lastLap : Maybe Int
    }


{-| 複数 Series を横軸(ラップタイム)で揃えるための共有ドメイン. 全 `times` の extent に
両側マージンを足して返す. すべての `times` が空のときは `Nothing`.
-}
domainOf : List Series -> Maybe ( Float, Float )
domainOf seriesList =
    let
        allTimes =
            seriesList |> List.concatMap .times |> List.map toFloat
    in
    Statistics.extent allTimes
        |> Maybe.map
            (\( lo, hi ) ->
                let
                    margin =
                        (hi - lo) * 0.1 + 1
                in
                ( lo - margin, hi + margin )
            )


{-| 共有ドメイン内で全 Series の密度の最大値を返す. 複数チャートで Y軸(密度)スケールを
揃えるために使う. KDE は面積1の確率密度なので, この最大値で正規化すると曲線の高さが
そのまま「分布の尖り＝ペースの安定度」の比較になる. データが無ければ床値を返す.
-}
maxDensityOf : ( Float, Float ) -> List Series -> Float
maxDensityOf domain seriesList =
    seriesList
        |> List.filter (\s -> not (List.isEmpty s.times))
        |> List.concatMap (\s -> (densityOf domain s).samples |> List.map Tuple.second)
        |> List.maximum
        |> Maybe.withDefault 1
        |> (\m -> max m 1.0e-9)


{-| 与えられた共有ドメインと共有 `maxDensity` で, 各 Series の KDE 密度曲線を重ねて描く.
塗り(area)＋実線(line)に加え, 直近ラップへ小マーカーとラップタイムラベルを置く.
Y軸を呼び出し側が渡す `maxDensity` で張ることで, 別々に描く複数チャートの高さを揃える.
全 `times` が空の Series は無視し, 描くものが無ければ空を返す.
-}
view : { width : Float, height : Float, domain : ( Float, Float ), maxDensity : Float } -> List Series -> Html msg
view { width, height, domain, maxDensity } seriesList =
    let
        densities =
            seriesList
                |> List.filter (\s -> not (List.isEmpty s.times))
                |> List.map (densityOf domain)
    in
    if List.isEmpty densities then
        text ""

    else
        let
            xScale =
                Scale.linear ( padLeft, width - padRight ) domain

            yScale =
                Scale.linear ( height - padBottom, padTop ) ( 0, maxDensity )
        in
        svg
            [ SvgAttr.width "100%"
            , SvgAttr.css [ property "display" "block" ]
            , viewBox 0 0 width height
            ]
            (xAxis height xScale
                :: List.map (densityShape xScale yScale) densities
            )



-- KDE


{-| KDE をサンプリングする点数(ドメインの等分割数).
-}
sampleCount : Int
sampleCount =
    64


{-| Epanechnikov カーネル. `|u| <= 1` の外では 0.
-}
epanechnikov : Float -> Float
epanechnikov u =
    if abs u <= 1 then
        0.75 * (1 - u * u)

    else
        0


{-| Silverman の経験則によるバンド幅 `1.06 * σ * n^(-1/5)`. ゼロ割を避ける床(1ms)を設ける.
-}
bandwidth : List Float -> Float
bandwidth xs =
    let
        n =
            List.length xs
    in
    case Statistics.deviation xs of
        Just sd ->
            max 1 (1.06 * sd * toFloat n ^ (-1 / 5))

        Nothing ->
            1


{-| バンド幅 `h`・標本 `xs` のもとでの点 `x` における密度. `d(x) = Σ k((x−t)/h) / (n·h)`.
-}
densityAt : Float -> List Float -> Float -> Float
densityAt h xs x =
    case xs of
        [] ->
            0

        _ ->
            (xs |> List.map (\t -> epanechnikov ((x - t) / h)) |> List.sum)
                / (toFloat (List.length xs) * h)


{-| ドメインを `sampleCount` 等分した x 列.
-}
samplePoints : ( Float, Float ) -> List Float
samplePoints ( lo, hi ) =
    List.range 0 (sampleCount - 1)
        |> List.map (\i -> lo + (hi - lo) * toFloat i / toFloat (sampleCount - 1))


type alias Density =
    { series : Series
    , samples : List ( Float, Float )
    , lastLapPoint : Maybe ( Float, Float )
    }


densityOf : ( Float, Float ) -> Series -> Density
densityOf domain series =
    let
        xs =
            List.map toFloat series.times

        h =
            bandwidth xs
    in
    { series = series
    , samples = samplePoints domain |> List.map (\x -> ( x, densityAt h xs x ))
    , lastLapPoint =
        series.lastLap
            |> Maybe.map (\ms -> ( toFloat ms, densityAt h xs (toFloat ms) ))
    }



-- RENDER


densityShape : ContinuousScale Float -> ContinuousScale Float -> Density -> Svg msg
densityShape xScale yScale { series, samples, lastLapPoint } =
    let
        scaled =
            samples
                |> List.map (\( x, d ) -> ( Scale.convert xScale x, Scale.convert yScale d ))

        baseline =
            Scale.convert yScale 0

        areaPoints =
            scaled |> List.map (\( px, py ) -> Just ( ( px, baseline ), ( px, py ) ))

        linePoints =
            scaled |> List.map Just
    in
    g []
        [ Path.element (Shape.area Shape.monotoneInXCurve areaPoints)
            [ SvgAttr.fill ("oklch(from " ++ series.color.value ++ " l c h / 0.15)") ]
        , Path.element (Shape.line Shape.monotoneInXCurve linePoints)
            [ SvgAttr.stroke series.color.value
            , SvgAttr.strokeWidth "2"
            , SvgAttr.fill "none"
            ]
        , lastLapMarker xScale yScale series lastLapPoint
        ]


{-| 直近ラップ(`lastLap`)が分布曲線上のどこに位置するかを小ドット＋ラップタイムラベルで示す.
`lastLap` が無ければ何も描かない.
-}
lastLapMarker : ContinuousScale Float -> ContinuousScale Float -> Series -> Maybe ( Float, Float ) -> Svg msg
lastLapMarker xScale yScale series lastLapPoint =
    case lastLapPoint of
        Just ( x, d ) ->
            let
                px =
                    Scale.convert xScale x

                py =
                    Scale.convert yScale d
            in
            g []
                [ circle
                    [ InPx.cx px
                    , InPx.cy py
                    , InPx.r 2.5
                    , SvgAttr.css [ Css.fill series.color ]
                    ]
                    []
                , text_
                    [ InPx.x px
                    , InPx.y (py - 6)
                    , SvgAttr.textAnchor "middle"
                    , SvgAttr.css
                        [ Css.fill series.color
                        , Css.fontSize (Css.px 9)
                        ]
                    ]
                    [ text (Duration.toString (round x)) ]
                ]

        Nothing ->
            text ""


xAxis : Float -> ContinuousScale Float -> Svg msg
xAxis height xScale =
    g [ transform [ Translate 0 (height - padBottom) ], css axisStyles ]
        [ fromUnstyled <|
            Axis.bottom
                [ Axis.tickCount 4
                , Axis.tickFormat (round >> Duration.toString)
                , Axis.tickSizeOuter 0
                ]
                xScale
        ]


axisStyles : List Style
axisStyles =
    [ descendants
        [ each [ typeSelector "line", typeSelector "path" ]
            [ property "stroke" "hsl(0 0% 100% / 0.3)" ]
        , typeSelector "text"
            [ property "fill" "hsl(0 0% 100% / 0.5)"
            , property "font-size" "8px"
            ]
        ]
    ]



-- DIMENSIONS


padLeft : Float
padLeft =
    4


padRight : Float
padRight =
    4


padTop : Float
padTop =
    16


padBottom : Float
padBottom =
    18
