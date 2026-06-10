module Motorsport.Widget.SelectedCarsStrip exposing (view)

{-| その瞬間の総合上位数台について、直前ラップの確定値・ベスト・セクター成績を
横並びカードで表示する Widget. 選択操作なしでレース先頭の状況を俯瞰できる.

@docs view

-}

import Css exposing (backgroundColor, batch, before, num, opacity, property, qt)
import Html.Styled exposing (Html, button, div, img, text)
import Html.Styled.Attributes as Attributes exposing (alt, class, css, src)
import Html.Styled.Events exposing (onClick)
import Motorsport.Car exposing (Status(..))
import Motorsport.Class as Class
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Lap.Performance as Performance
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Standings as Standings exposing (Standings, StandingsEntry)


{-| `offset` は表示ウィンドウの先頭順位(0始まり). `onScrollTo` には移動先 offset を渡す.
範囲外の offset は内部でクランプされるため, 呼び出し側はそのまま保持してよい.
-}
view : { season : Int, offset : Int, onScrollTo : Int -> msg } -> Standings -> Html msg
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
                    , property "padding" "8px"
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
                    (List.map (carCard { season = config.season }) window)
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
        , class "btn btn-circle btn-sm btn-ghost text-xs"
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


carCard : { season : Int } -> StandingsEntry -> Html msg
carCard { season } item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-rows" "auto auto auto auto 1fr"
            , property "row-gap" "4px"
            , property "padding" "6px 8px"
            , property "border-radius" "6px"
            , property "background-color" "hsl(0 0% 100% / 0.05)"
            ]
        ]
        [ cardHeader season item
        , gapsRow item
        , lastLapRow item
        , bestLapRow item
        ]


cardHeader : Int -> StandingsEntry -> Html msg
cardHeader season item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr auto auto"
            , property "align-items" "center"
            , property "column-gap" "6px"
            ]
        ]
        [ carNumberBadge item
        , div
            [ css
                [ property "font-size" "10px"
                , property "font-weight" "600"
                , property "white-space" "nowrap"
                , property "overflow" "hidden"
                , property "text-overflow" "ellipsis"
                ]
            ]
            [ text (item.currentDriver |> Maybe.map (.name >> formatDriverName) |> Maybe.withDefault "") ]
        , statusBadge item.status
        , positionLabel season item
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
    div
        [ class "grid grid-cols-[20px_25px] gap-1 place-items-center rounded"
        , css
            [ property "padding" "2px"
            , backgroundColor (Manufacturer.toColor item.metadata.manufacturer)
            ]
        ]
        [ case Manufacturer.toLogoUrl item.metadata.manufacturer of
            Just url ->
                img
                    [ src url
                    , alt (Manufacturer.toString item.metadata.manufacturer)
                    , css
                        [ property "height" "14px"
                        , property "object-fit" "contain"
                        ]
                    ]
                    []

            Nothing ->
                div [] []
        , div
            [ css
                [ property "font-size" "11px"
                , property "font-weight" "700"
                , property "line-height" "1"
                ]
            ]
            [ text item.metadata.carNumber ]
        ]


positionLabel : Int -> StandingsEntry -> Html msg
positionLabel season item =
    div
        [ css
            [ property "display" "flex"
            , property "align-items" "center"
            , property "column-gap" "4px"
            , property "font-size" "10px"
            , property "font-weight" "700"
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
            , property "grid-template-columns" "auto 1fr 1fr"
            , property "align-items" "baseline"
            , property "column-gap" "8px"
            , property "font-size" "10px"
            , opacity (num 0.75)
            ]
        ]
        [ div []
            [ text ("L " ++ String.fromInt item.lapsCompleted) ]
        , gapCell "Leader" item.gapToLeader
        , gapCell "Ahead" item.intervalToAhead
        ]


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
        [ div
            [ css
                [ property "font-size" "9px"
                , opacity (num 0.7)
                ]
            ]
            [ text label ]
        , div
            [ css [ property "text-align" "right" ] ]
            [ text (Gap.toString gap) ]
        ]


lastLapRow : StandingsEntry -> Html msg
lastLapRow item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr auto"
            , property "align-items" "baseline"
            , property "column-gap" "6px"
            ]
        ]
        [ labelText "Last"
        , div
            [ css
                [ property "font-size" "13px"
                , property "font-variant-numeric" "tabular-nums"
                , property "text-align" "right"
                , case item.lastLap of
                    Just { performance } ->
                        if Performance.isStandard performance then
                            batch []

                        else
                            property "color" (Performance.toColorVariable performance)

                    Nothing ->
                        batch []
                ]
            ]
            [ text (item.lastLap |> Maybe.map (.time >> Duration.toString) |> Maybe.withDefault "-") ]
        , deltaBadge item
        ]


bestLapRow : StandingsEntry -> Html msg
bestLapRow item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr"
            , property "align-items" "baseline"
            , property "column-gap" "6px"
            ]
        ]
        [ labelText "Best"
        , div
            [ css
                [ property "font-size" "11px"
                , property "font-variant-numeric" "tabular-nums"
                , property "text-align" "right"
                ]
            ]
            [ text (item.bestLap |> Maybe.map (.time >> Duration.toString) |> Maybe.withDefault "-") ]
        ]


labelText : String -> Html msg
labelText label =
    div
        [ css
            [ property "font-size" "9px"
            , opacity (num 0.6)
            ]
        ]
        [ text label ]


deltaBadge : StandingsEntry -> Html msg
deltaBadge item =
    case ( item.lastLap, item.bestLap ) of
        ( Just last, Just best ) ->
            let
                deltaMs =
                    last.time - best.time
            in
            if deltaMs <= 0 then
                div
                    [ css
                        [ property "font-size" "9px"
                        , opacity (num 0.5)
                        ]
                    ]
                    [ text "=" ]

            else
                div
                    [ css
                        [ property "font-size" "10px"
                        , property "font-variant-numeric" "tabular-nums"
                        , opacity (num 0.85)
                        ]
                    ]
                    [ text ("+" ++ formatDelta deltaMs) ]

        _ ->
            text ""


formatDelta : Int -> String
formatDelta ms =
    let
        seconds =
            toFloat ms / 1000

        rounded =
            ((seconds * 1000) |> round |> toFloat) / 1000
    in
    String.fromFloat rounded


formatDriverName : String -> String
formatDriverName fullName =
    case String.words fullName of
        _ :: rest ->
            rest |> List.map String.toUpper |> String.join " "

        [] ->
            fullName
