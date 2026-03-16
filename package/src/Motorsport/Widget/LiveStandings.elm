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
import SortedList


type alias Props msg =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , onSelectCar : ViewModelItem -> msg
    }


view : Props msg -> Html msg
view props =
    let
        carList =
            props.viewModel.items
                |> SortedList.toList
                |> List.map
                    (\item ->
                        ( item.metadata.carNumber
                        , Lazy.lazy2 carRow props.onSelectCar item
                        )
                    )
    in
    div
        [ css
            [ property "height" "100%"
            , property "display" "grid"
            , property "grid-template-rows" "repeat(3, 195px)"
            , property "row-gap" "15px"
            ]
        ]
        (List.map
            (\( class_, cars ) ->
                div
                    [ css
                        [ property "height" "100%"
                        , property "display" "grid"
                        , property "grid-template-rows" "auto 1fr"
                        , property "row-gap" "4px"
                        ]
                    ]
                    [ div
                        [ css
                            [ property "display" "flex"
                            , property "align-items" "center"
                            , property "column-gap" "0.5em"
                            , property "font-size" "10px"
                            , property "font-weight" "bold"
                            , before
                                [ property "display" "block"
                                , property "content" (qt "")
                                , property "width" "0.2em"
                                , property "height" "1.2em"
                                , property "border-radius" "2px"
                                , backgroundColor (Class.toHexColor props.eventSummary.season class_)
                                ]
                            ]
                        ]
                        [ text (Class.toString class_) ]
                    , Keyed.node "ul"
                        [ class "list"
                        , css
                            [ property "overflow-y" "scroll" ]
                        ]
                        (cars
                            |> SortedList.toList
                            |> List.map
                                (\item ->
                                    ( item.metadata.carNumber
                                    , Lazy.lazy2 carRow props.onSelectCar item
                                    )
                                )
                        )
                    ]
            )
            props.viewModel.itemsByClass
        )


formatDriverName : String -> String
formatDriverName fullName =
    case String.words fullName of
        _ :: rest ->
            -- 姓全体を大文字で表示
            rest |> List.map String.toUpper |> String.join " "

        [] ->
            fullName


carRow : (ViewModelItem -> msg) -> ViewModelItem -> Html msg
carRow onSelect item =
    li
        [ onClick (onSelect item)
        , class "list-row p-0.5 grid-cols-[20px_auto_1fr_auto_24px] items-center gap-2"
        , css
            [ property "cursor" "pointer"
            , property "transition" "background-color 0.2s ease"
            , after [ property "border" "none" ]
            , hover [ property "background-color" "hsl(0 0% 100% / 0.05)" ]
            ]
        ]
        [ div [ class "text-center text-xs" ] [ text (String.fromInt item.position) ]
        , div
            [ class "p-1 grid grid-cols-[20px_25px] gap-1 place-items-center rounded"
            , css [ backgroundColor (Manufacturer.toColor item.metadata.manufacturer) ]
            ]
            [ case Manufacturer.toLogoUrl item.metadata.manufacturer of
                Just logoUrl ->
                    img
                        [ src logoUrl
                        , alt (Manufacturer.toString item.metadata.manufacturer)
                        , class "object-contain"
                        , css [ property "height" "14px" ]
                        ]
                        []

                Nothing ->
                    div [] [ text "" ]
            , div [ class "text-center leading-none text-xs font-bold" ]
                [ text item.metadata.carNumber ]
            ]
        , div [ class "text-xs opacity-70" ]
            [ text (item.currentDriver |> Maybe.map (.name >> formatDriverName) |> Maybe.withDefault "") ]
        , div [ class "text-xs text-right" ]
            [ text (Gap.toString item.timing.interval) ]
        , if item.status == Car.InPit then
            div
                [ class "w-4 h-4 rounded-full border border-white-500 flex items-center justify-center text-white text-[9px] font-bold" ]
                [ text "P" ]

          else
            text ""
        ]
