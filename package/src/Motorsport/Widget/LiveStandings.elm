module Motorsport.Widget.LiveStandings exposing (Props, view)

import Css exposing (after, before, hover, property, qt)
import Html.Styled exposing (Html, button, div, li, text)
import Html.Styled.Attributes exposing (attribute, class, css)
import Html.Styled.Events exposing (onClick)
import Html.Styled.Keyed as Keyed
import Html.Styled.Lazy as Lazy
import Motorsport.Class as Class
import Motorsport.Driver as Driver
import Motorsport.Gap as Gap
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Status as Status
import Motorsport.Widget.CarNumberBadge as CarNumberBadge


type alias Props msg =
    { snapshot : Snapshot

    -- Returns the carNumber of the selected car.
    -- To keep Lazy effective, pass a stable reference such as a Msg constructor,
    -- not a closure that is recreated on every view.
    , onSelectCar : String -> msg
    , popoverTarget : String
    }


view : Props msg -> Html msg
view props =
    div
        [ css
            [ property "height" "100%"
            , property "display" "grid"
            , property "grid-template-rows" "repeat(3, 1fr)"
            , property "row-gap" "10px"
            ]
        ]
        (List.map
            (\( class_, cars ) ->
                div
                    [ class "card bg-base-200 overflow-hidden"
                    , css
                        [ property "display" "grid"
                        , property "grid-template-rows" "auto 1fr"
                        ]
                    ]
                    [ div
                        [ css
                            [ property "display" "flex"
                            , property "align-items" "center"
                            , property "column-gap" "0.5em"
                            , property "padding" "8px 10px"
                            , property "font-size" "10px"
                            , property "font-weight" "bold"
                            , before
                                [ property "display" "block"
                                , property "content" (qt "")
                                , property "width" "0.2em"
                                , property "height" "1.2em"
                                , property "border-radius" "2px"
                                , property "background-color" (Class.toColor class_).value
                                ]
                            ]
                        ]
                        [ text (Class.toString class_) ]
                    , Keyed.node "ul"
                        [ class "list"
                        , css
                            [ property "overflow-y" "scroll"
                            , property "padding" "0 10px 10px"
                            ]
                        ]
                        (cars
                            |> List.map
                                (\item ->
                                    ( item.metadata.carNumber
                                    , Lazy.lazy3 carRow props.popoverTarget props.onSelectCar item
                                    )
                                )
                        )
                    ]
            )
            (Snapshot.toClassList props.snapshot)
        )


carRow : String -> (String -> msg) -> CarAt -> Html msg
carRow popoverTarget onSelect item =
    li []
        [ button
            [ onClick (onSelect item.metadata.carNumber)
            , attribute "popovertarget" popoverTarget

            -- Explicit "show": the default "toggle" would close the shared
            -- popover when a second row is clicked while it is already open.
            , attribute "popovertargetaction" "show"
            , class "list-row w-full p-0.5 grid grid-cols-[20px_auto_1fr_auto_24px] items-center gap-2 text-left"
            , css
                [ property "background" "none"
                , property "border" "none"
                , property "color" "inherit"
                , property "font" "inherit"
                , property "cursor" "pointer"
                , property "transition" "background-color 0.2s ease"
                , after [ property "border" "none" ]
                , hover [ property "background-color" "hsl(0 0% 100% / 0.05)" ]
                ]
            ]
            (carRowContent item)
        ]


carRowContent : CarAt -> List (Html msg)
carRowContent item =
    [ div [ class "text-center text-xs" ] [ text (String.fromInt item.position) ]
    , CarNumberBadge.viewRow item.metadata
    , div [ class "text-xs opacity-70" ]
        [ text (item.currentDriver |> Maybe.withDefault Driver.unknown |> Driver.toSurname) ]
    , div [ class "text-xs text-right" ]
        [ text (Gap.toString item.intervalToAhead) ]
    , if item.status == Status.InPit then
        div
            [ class "w-4 h-4 rounded-full border border-white-500 flex items-center justify-center text-white text-[9px] font-bold" ]
            [ text "P" ]

      else
        text ""
    ]
