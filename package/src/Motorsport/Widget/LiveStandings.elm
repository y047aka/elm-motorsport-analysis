module Motorsport.Widget.LiveStandings exposing (Props, view)

import Css exposing (backgroundColor, before, property, qt)
import Data.Series.EventSummary exposing (EventSummary)
import Html.Styled as Html exposing (Html, div, img, table, td, text, tr)
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
                    , div [ class "overflow-y-auto" ]
                        [ table [ class "table table-xs" ]
                            [ Keyed.node "tbody"
                                []
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
                        ]
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
    tr
        [ onClick (onSelect item)
        , class "hover:bg-base-200/10 cursor-pointer transition-colors [&>td]:px-1"
        ]
        [ td [ class "text-center" ] [ text (String.fromInt item.position) ]
        , td [] [ manufacturerBadge item ]
        , td [ class "opacity-70 w-full" ]
            [ text (item.currentDriver |> Maybe.map (.name >> formatDriverName) |> Maybe.withDefault "") ]
        , td [ class "text-right" ]
            [ text (Gap.toString item.timing.interval) ]
        , td []
            [ if item.status == Car.InPit then
                pitStatusBadge

              else
                text ""
            ]
        ]


manufacturerBadge : ViewModelItem -> Html msg
manufacturerBadge item =
    div
        [ class "p-1 grid grid-cols-[20px_25px] gap-1 place-items-center rounded"
        , css [ backgroundColor (Manufacturer.toColor item.metadata.manufacturer) ]
        ]
        [ case Manufacturer.toLogoUrl item.metadata.manufacturer of
            Just logoUrl ->
                img
                    [ src logoUrl
                    , alt (Manufacturer.toString item.metadata.manufacturer)
                    , class "object-contain h-3.5"
                    ]
                    []

            Nothing ->
                div [] [ text "" ]
        , div [ class "text-center leading-none font-bold" ]
            [ text item.metadata.carNumber ]
        ]


pitStatusBadge : Html msg
pitStatusBadge =
    Html.span
        [ class "badge badge-outline badge-xs w-4 h-4 p-0 flex items-center justify-center rounded-full" ]
        [ text "P" ]
