module Motorsport.Widget.LiveStandings exposing (view)

{-| The field by class, in running order, and the page's one place for picking
the car everything else is shown for.

@docs view

-}

import Html exposing (Html, button, div, li, text)
import Html.Attributes exposing (attribute, class)
import Html.Events exposing (onClick)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Motorsport.Driver as Driver
import Motorsport.Race.Car exposing (CarNumber, Metadata)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Status as Status
import Motorsport.Wec.Class as Class
import Motorsport.Widget.CarNumberBadge as CarNumberBadge


{-| `selected` is the car the rest of the page is following; clicking its row
fires `onSelect` with it again, which is how the selection is let go of.
-}
view : { onSelect : CarNumber -> msg, selected : Maybe CarNumber } -> Snapshot -> Html msg
view { onSelect, selected } snapshot =
    div
        [ class "h-full grid auto-rows-[minmax(0,1fr)] gap-y-2.5" ]
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
                                    , Lazy.lazy6 carRow
                                        onSelect
                                        item.metadata
                                        item.standing.position
                                        (Driver.toSurname item.currentDriver)
                                        (item.status == Status.InPit)
                                        (selected == Just item.metadata.carNumber)
                                    )
                                )
                        )
                    ]
            )
            (Snapshot.toClassList snapshot)
        )


{-| Takes the row's pieces rather than the `CarAt` they are read off. A thunk's
arguments are compared by `===`, and a `CarAt` is built afresh at every clock;
the metadata is the car's own, which the race holds still, and the rest are
primitives. `onSelect` is the caller's own tag, which is held still too.

The row reads as the number of the car it picks rather than as its three
columns, which are the position and driver the reader already has in front of
them.

-}
carRow : (CarNumber -> msg) -> Metadata -> Int -> String -> Bool -> Bool -> Html msg
carRow onSelect metadata position driverSurname isInPit isSelected =
    li []
        [ button
            [ onClick (onSelect metadata.carNumber)
            , attribute "aria-label" ("Car #" ++ metadata.carNumber)
            , attribute "aria-pressed"
                (if isSelected then
                    "true"

                 else
                    "false"
                )
            , class "relative w-full p-0.5 grid grid-cols-[20px_auto_1fr] items-center gap-2 text-left [word-break:break-word] rounded cursor-pointer transition-colors"
            , class
                (if isSelected then
                    "bg-accent text-accent-foreground"

                 else
                    "hover:bg-accent/40"
                )
            ]
            [ div [ class "text-center text-xs" ] [ text (String.fromInt position) ]
            , CarNumberBadge.viewRow metadata
            , div [ class "text-xs" ]
                [ text driverSurname ]
            , if isInPit then
                div
                    [ class "absolute right-1 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full border border-border flex items-center justify-center text-white text-[9px] font-bold bg-card" ]
                    [ text "P" ]

              else
                text ""
            ]
        ]
