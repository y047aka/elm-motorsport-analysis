module Motorsport.Widget.LiveStandings exposing (ListProps, view)

import Css exposing (after, backgroundColor, hover, property)
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, li, text, ul)
import Html.Styled.Attributes exposing (class, css)
import Html.Styled.Events exposing (onClick)
import Motorsport.Class as Class
import Motorsport.Gap as Gap
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget as Widget
import SortedList


type alias ListProps msg =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , onSelectCar : ViewModelItem -> msg
    }


view : ListProps msg -> Html msg
view props =
    let
        headerTitle =
            props.eventSummary.name ++ " (" ++ String.fromInt props.eventSummary.season ++ ")"

        carList =
            props.viewModel.items
                |> SortedList.toList
                |> List.map (carRow props.eventSummary.season props.onSelectCar)
    in
    Widget.container headerTitle <|
        ul [ class "list" ] carList


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
