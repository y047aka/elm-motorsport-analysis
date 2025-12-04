module Motorsport.Widget.LiveStandings exposing (Props, view)

import Css exposing (after, backgroundColor, before, hover, property, qt)
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, img, li, text)
import Html.Styled.Attributes exposing (alt, class, css, src)
import Html.Styled.Events exposing (onClick)
import Html.Styled.Keyed as Keyed
import Html.Styled.Lazy as Lazy
import Motorsport.Car as Car
import Motorsport.Class as Class
import Motorsport.Gap as Gap
import Motorsport.Manufacturer as Manufacturer
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
    div
        [ css
            [ property "height" "100%"
            , property "display" "grid"
            , property "grid-template-rows" "repeat(3, 330px)"
            ]
        ]
        (List.map
            (\( class_, cars ) ->
                div
                    [ css
                        [ property "height" "100%"
                        , property "display" "grid"
                        , property "grid-template-rows" "auto 1fr"
                        ]
                    ]
                    [ div
                        [ css
                            [ property "padding-block" "0.25rem"
                            , property "display" "flex"
                            , property "align-items" "center"
                            , property "column-gap" "0.5em"
                            , property "font-weight" "bold"
                            , property "font-size" "0.875rem"
                            , before
                                [ property "display" "block"
                                , property "content" (qt "")
                                , property "width" "1em"
                                , property "height" "1em"
                                , property "border-radius" "2px"
                                , backgroundColor (Class.toHexColor props.eventSummary.season class_)
                                ]
                            ]
                        ]
                        [ text (Class.toString class_) ]
                    , Keyed.node "ul"
                        [ class "list"
                        , css
                            [ property "overflow" "scroll" ]
                        ]
                        (cars
                            |> SortedList.toList
                            |> List.map
                                (\item ->
                                    ( item.metadata.carNumber
                                    , Lazy.lazy3 carRow props.eventSummary.season props.onSelectCar item
                                    )
                                )
                        )
                    ]
            )
            props.viewModel.itemsByClass
        )


carRow : Int -> (ViewModelItem -> msg) -> ViewModelItem -> Html msg
carRow season onSelect item =
    li
        [ onClick (onSelect item)
        , class "list-row p-2 grid-cols-[20px_60px_1fr_auto_24px] items-center gap-2"
        , css
            [ after [ property "border-color" "hsl(0 0% 100% / 0.1)" ]
            , property "cursor" "pointer"
            , property "transition" "background-color 0.2s ease"
            , hover [ property "background-color" "hsl(0 0% 100% / 0.05)" ]
            ]
        ]
        [ div [ class "text-center text-xs" ] [ text (String.fromInt item.position) ]
        , div
            [ class "flex items-center justify-center gap-1 py-1 px-1.5 text-xs font-bold rounded"
            , css [ backgroundColor (Manufacturer.toColor item.metadata.manufacturer) ]
            ]
            (case Manufacturer.toLogoUrl item.metadata.manufacturer of
                Just logoUrl ->
                    [ img
                        [ src logoUrl
                        , alt (Manufacturer.toString item.metadata.manufacturer)
                        , class "object-contain"
                        , css
                            [ property "max-width" "18px"
                            , property "max-height" "18px"
                            ]
                        ]
                        []
                    , text item.metadata.carNumber
                    ]

                Nothing ->
                    [ text item.metadata.carNumber ]
            )
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
