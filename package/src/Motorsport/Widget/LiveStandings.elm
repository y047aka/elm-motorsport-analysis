module Motorsport.Widget.LiveStandings exposing (Props, view)

import Css exposing (after, backgroundColor, fontSize, hover, padding2, property, px, width)
import Data.Series as Series
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, button, div, img, li, text, ul)
import Html.Styled.Attributes exposing (class, css, src)
import Html.Styled.Events exposing (onClick)
import Motorsport.Class as Class
import Motorsport.Gap as Gap
import Motorsport.Lap.Performance as Performance
import Motorsport.Leaderboard as Leaderboard
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget as Widget
import SortedList


type alias Props msg =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , selectedCar : Maybe ViewModelItem
    , onSelectCar : ViewModelItem -> msg
    , onCloseModal : msg
    }


view : Props msg -> Html msg
view props =
    let
        headerTitle =
            props.eventSummary.name ++ " (" ++ String.fromInt props.eventSummary.season ++ ")"

        carList =
            props.viewModel.items
                |> SortedList.toList
                |> List.map (carRow props.eventSummary.season props.onSelectCar)

        content =
            div []
                [ ul [ class "list" ] carList
                , modalView props
                ]
    in
    Widget.container headerTitle content


carRow : Int -> (ViewModelItem -> msg) -> ViewModelItem -> Html msg
carRow season onSelect item =
    li
        [ onClick (onSelect item)
        , class "list-row p-2 grid-cols-[20px_30px_1fr_auto] items-center gap-2"
        , css
            [ after [ property "border-color" "hsl(0 0% 100% / 0.1)" ]
            , property "cursor" "pointer"
            , property "transition" "background-color 0.2s ease"
            , hover [ property "background-color" "hsl(0 0% 100% / 0.05)" ]
            ]
        ]
        [ div [ class "text-center text-xs" ] [ text (String.fromInt item.position) ]
        , div
            [ class "py-1 text-center text-xs font-bold rounded"
            , css [ backgroundColor (Class.toHexColor season item.metadata.class) ]
            ]
            [ text item.metadata.carNumber ]
        , div []
            [ div [ class "text-xs" ] [ text item.metadata.team ]
            , div [ class "text-xs opacity-60" ]
                [ text (item.currentDriver |> Maybe.map .name |> Maybe.withDefault "") ]
            ]
        , div [ class "text-xs text-right" ]
            [ text (Gap.toString item.timing.interval) ]
        ]


modalView : Props msg -> Html msg
modalView props =
    case props.selectedCar of
        Nothing ->
            Html.text ""

        Just item ->
            div
                [ class "modal modal-open" ]
                [ div [ class "modal-box w-full max-w-md p-6 bg-base-200" ]
                    [ modalHeader props.onCloseModal props.eventSummary.season item
                    , modalDetails props.eventSummary item
                    ]
                ]


modalHeader : msg -> Int -> ViewModelItem -> Html msg
modalHeader onClose season item =
    let
        carImage carNumber =
            case Series.carImageUrl_Wec season carNumber of
                Just url ->
                    img [ src url, css [ width (px 100) ] ] []

                Nothing ->
                    text ""
    in
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto auto 1fr auto"
            , property "align-items" "center"
            , property "column-gap" "10px"
            ]
        ]
        [ carImage item.metadata.carNumber
        , Leaderboard.viewCarNumberColumn_Wec season item.metadata
        , Leaderboard.viewDriverAndTeamColumn_Wec item
        , button
            [ onClick onClose
            , class "btn btn-sm"
            , css
                [ fontSize (px 14)
                , padding2 (px 6) (px 10)
                ]
            ]
            [ text "Close" ]
        ]


modalDetails : EventSummary -> ViewModelItem -> Html msg
modalDetails eventSummary item =
    let
        analysis =
            let
                laps =
                    item.history
            in
            { fastestLapTime = [ laps ] |> Performance.findFastest |> Maybe.map .time |> Maybe.withDefault 0
            , slowestLapTime = [ laps ] |> Performance.findSlowest |> Maybe.map .time |> Maybe.withDefault 0
            , sector_1_fastest = [ laps ] |> Performance.findFastestBy .sector_1 |> Maybe.withDefault 0
            , sector_2_fastest = [ laps ] |> Performance.findFastestBy .sector_2 |> Maybe.withDefault 0
            , sector_3_fastest = [ laps ] |> Performance.findFastestBy .sector_3 |> Maybe.withDefault 0
            , miniSectorFastest = Performance.calculateMiniSectorFastest [ laps ]
            }
    in
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "1fr 1fr"
            , property "column-gap" "12px"
            ]
        ]
        [ div []
            [ Html.div [ class "text-xs opacity-60" ] [ text "Current Lap" ]
            , (case ( eventSummary.season, eventSummary.name ) of
                ( 2025, "24 Hours of Le Mans" ) ->
                    Leaderboard.viewCurrentLapColumn_LeMans24h

                _ ->
                    Leaderboard.viewCurrentLapColumn_Wec
              )
                analysis
                item
            ]
        , div []
            [ Html.div [ class "text-xs opacity-60" ] [ text "Last Lap" ]
            , (case ( eventSummary.season, eventSummary.name ) of
                ( 2025, "24 Hours of Le Mans" ) ->
                    Leaderboard.viewLastLapColumn_LeMans24h

                _ ->
                    Leaderboard.viewLastLapColumn_Wec
              )
                analysis
                item.lastLap
            ]
        ]
