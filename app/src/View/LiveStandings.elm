module View.LiveStandings exposing (view)

{-| The field by class, in running order, and the page's one place for picking
the cars the middle of it is given over to.

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
import View.CarNumberBadge as CarNumberBadge


{-| A row is marked when its car has a column -- the cars standing in before
anything has been chosen among them included, a stand-in having a column like
any other. Clicking a row hands `onSelect` the car it names and it is given
one; clicking a marked row does nothing, and there is no clicking a car away
again. A mark comes off only when that row's column is closed, which is done
from the column itself.

`onSelect` is held as it is handed over, so pass a message constructor: the
rows are thunked, and a lambda or a composition built afresh on each render
compares unequal and draws every one of them again.

-}
view : { onSelect : CarNumber -> msg, withColumns : List CarNumber } -> Snapshot -> Html msg
view { onSelect, withColumns } snapshot =
    div
        -- Marked, which the visual tests locate the standings by: the cell it
        -- sits in is named by the Tailwind utilities that place it, and those
        -- are not its own -- a panel's header grid places its cells with the
        -- same ones.
        [ attribute "data-live-standings" ""
        , class "h-full grid auto-rows-[minmax(0,1fr)] gap-y-2.5"
        ]
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
                                        (List.member item.metadata.carNumber withColumns)
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
carRow onSelect metadata position driverSurname isInPit hasColumn =
    li []
        [ button
            ([ attribute "aria-label" ("Car #" ++ metadata.carNumber)
             , attribute "aria-pressed"
                (if hasColumn then
                    "true"

                 else
                    "false"
                )
             , class "relative w-full p-0.5 grid grid-cols-[20px_auto_1fr] items-center gap-2 text-left [word-break:break-word] rounded transition-colors"
             ]
                ++ (if hasColumn then
                        -- No handler: the car already has a column, and the
                        -- press that would give it one is the press that
                        -- gave it the one it has.
                        [ class "bg-accent text-accent-foreground" ]

                    else
                        [ onClick (onSelect metadata.carNumber)
                        , class "cursor-pointer hover:bg-accent/40"
                        ]
                   )
            )
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
