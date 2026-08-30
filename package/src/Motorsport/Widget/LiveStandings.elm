module Motorsport.Widget.LiveStandings exposing (Props, view)

import Html exposing (Html, button, div, li, text)
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Motorsport.Driver as Driver
import Motorsport.Gap as Gap
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Status as Status
import Motorsport.Wec.Class as Class
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
        [ class "h-full grid grid-rows-[repeat(3,1fr)] gap-y-2.5" ]
        (List.map
            (\( class_, cars ) ->
                div
                    [ class "rounded-lg border border-border bg-card overflow-hidden grid grid-rows-[auto_1fr]" ]
                    [ div
                        [ class "flex items-center gap-x-[0.5em] py-2 px-2.5 text-[10px] font-bold before:block before:content-[''] before:w-[0.2em] before:h-[1.2em] before:rounded-[2px] before:[background-color:var(--class-color)]"
                        , attribute "style" ("--class-color: " ++ Class.toColor class_ ++ ";")
                        ]
                        [ text (Class.toString class_) ]
                    , Keyed.node "ul"
                        [ class "flex flex-col text-sm overflow-y-scroll p-[0_10px_10px]" ]
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
            , class "relative rounded-md w-full p-0.5 grid grid-cols-[20px_auto_1fr_auto_24px] items-center gap-2 text-left [word-break:break-word] cursor-pointer transition-colors hover:bg-accent"
            ]
            (carRowContent item)
        ]


carRowContent : CarAt -> List (Html msg)
carRowContent item =
    [ div [ class "text-center text-xs" ] [ text (String.fromInt item.standing.position) ]
    , CarNumberBadge.viewRow item.metadata
    , div [ class "text-xs opacity-70" ]
        [ text (Driver.toSurname item.currentDriver) ]
    , div [ class "text-xs text-right" ]
        [ text (Gap.toString item.standing.intervalToAhead) ]
    , if item.status == Status.InPit then
        div
            [ class "w-4 h-4 rounded-full border border-white-500 flex items-center justify-center text-white text-[9px] font-bold" ]
            [ text "P" ]

      else
        text ""
    ]
