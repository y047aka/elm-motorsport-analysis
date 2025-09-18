module Motorsport.Widget.LiveStandings exposing (Props, view)

import Css exposing (after, backgroundColor, fontSize, hover, padding2, property, px)
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, button, div, li, span, text, ul)
import Html.Styled.Attributes exposing (class, css)
import Html.Styled.Events exposing (onClick)
import Motorsport.Car exposing (statusToString)
import Motorsport.Class as Class
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
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
                [ class "car-modal-overlay"
                , css
                    [ property "position" "fixed"
                    , property "inset" "0"
                    , property "background-color" "hsl(0 0% 0% / 0.6)"
                    , property "display" "grid"
                    , property "place-items" "center"
                    , property "z-index" "50"
                    ]
                ]
                [ div
                    [ class "car-modal-content"
                    , css
                        [ property "width" "min(420px, 90vw)"
                        , property "background-color" "var(--widget-bg, hsl(240 8% 14%))"
                        , property "border-radius" "16px"
                        , property "padding" "20px"
                        , property "display" "grid"
                        , property "row-gap" "16px"
                        , property "box-shadow" "0 20px 40px hsl(0 0% 0% / 0.35)"
                        ]
                    ]
                    [ modalHeader props.onCloseModal item
                    , modalDetails item
                    ]
                ]


modalHeader : msg -> ViewModelItem -> Html msg
modalHeader onClose item =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "1fr auto"
            , property "align-items" "center"
            ]
        ]
        [ div []
            [ span
                [ css
                    [ fontSize (px 12)
                    , property "opacity" "0.7"
                    ]
                ]
                [ text ("POS " ++ String.fromInt item.position ++ " • Class " ++ String.fromInt item.positionInClass) ]
            , div
                [ css
                    [ fontSize (px 20)
                    , property "font-weight" "700"
                    ]
                ]
                [ text ("#" ++ item.metadata.carNumber ++ " " ++ item.metadata.team) ]
            ]
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


modalDetails : ViewModelItem -> Html msg
modalDetails item =
    let
        formatLastLap =
            item.lastLap
                |> Maybe.map (.time >> Duration.toString)
                |> Maybe.withDefault "-"

        formatCurrentDriver =
            item.currentDriver
                |> Maybe.map .name
                |> Maybe.withDefault "-"

        formatDrivers =
            if List.isEmpty item.metadata.drivers then
                "-"

            else
                item.metadata.drivers
                    |> List.map .name
                    |> String.join ", "
    in
    div
        [ css
            [ property "display" "grid"
            , property "row-gap" "12px"
            ]
        ]
        [ detailRow "Class" (Class.toString item.metadata.class)
        , detailRow "Status" (statusToString item.status)
        , detailRow "Gap" (Gap.toString item.timing.gap)
        , detailRow "Interval" (Gap.toString item.timing.interval)
        , detailRow "Current driver" formatCurrentDriver
        , detailRow "Drivers" formatDrivers
        , detailRow "Last lap" formatLastLap
        ]


detailRow : String -> String -> Html msg
detailRow label value =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "120px 1fr"
            , property "column-gap" "12px"
            , property "align-items" "center"
            ]
        ]
        [ span
            [ css
                [ fontSize (px 12)
                , property "opacity" "0.6"
                ]
            ]
            [ text label ]
        , span
            [ css [ fontSize (px 14) ] ]
            [ text value ]
        ]
