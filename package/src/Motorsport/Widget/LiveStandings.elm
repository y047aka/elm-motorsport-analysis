module Motorsport.Widget.LiveStandings exposing (Props, view)

import Css exposing (after, backgroundColor, hover, property)
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, li, text)
import Html.Styled.Attributes exposing (class, css)
import Html.Styled.Events exposing (onClick)
import Html.Styled.Keyed as Keyed
import Html.Styled.Lazy as Lazy
import Motorsport.Car as Car
import Motorsport.Class as Class
import Motorsport.Gap as Gap
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget as Widget
import SortedList


type alias Props msg =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , onSelectCar : ViewModelItem -> msg
    }


view : Props msg -> Html msg
view props =
    let
        headerTitle =
            props.eventSummary.name ++ " (" ++ String.fromInt props.eventSummary.season ++ ")"

        carList =
            props.viewModel.items
                |> SortedList.toList
                |> List.map
                    (\item ->
                        ( item.metadata.carNumber
                        , Lazy.lazy3 carRow props.eventSummary.season props.onSelectCar item
                        )
                    )
    in
    Widget.container headerTitle <|
        Keyed.node "ul" [ class "list" ] carList


carRow : Int -> (ViewModelItem -> msg) -> ViewModelItem -> Html msg
carRow season onSelect item =
    li
        [ onClick (onSelect item)
        , class "list-row p-2 grid-cols-[20px_30px_1fr_auto_24px] items-center gap-2"
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
        , if item.status == Car.InPit then
            div
                [ class "w-5 h-5 rounded-full border border-white-500 flex items-center justify-center text-white text-[10px] font-bold" ]
                [ text "P" ]

          else
            text ""
        ]
