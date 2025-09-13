module Motorsport.Widget.LiveStandings exposing (view)

import Css exposing (after, backgroundColor, property)
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, li, text, ul)
import Html.Styled.Attributes exposing (class, css)
import Motorsport.Class as Class
import Motorsport.Gap as Gap
import Motorsport.RaceControl.ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Widget as Widget
import SortedList


view : EventSummary -> ViewModel -> Html msg
view eventSummary viewModel =
    Widget.container (eventSummary.name ++ " (" ++ String.fromInt eventSummary.season ++ ")")
        (ul [ class "list" ]
            (viewModel.items
                |> SortedList.toList
                |> List.map (carRow eventSummary.season)
            )
        )


carRow : Int -> ViewModelItem -> Html msg
carRow season item =
    li
        [ class "list-row p-2 grid-cols-[20px_30px_1fr_80px] items-center gap-2"
        , css [ after [ property "border-color" "hsl(0 0% 100% / 0.1)" ] ]
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
