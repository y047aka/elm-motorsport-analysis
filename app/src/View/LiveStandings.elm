module View.LiveStandings exposing (view, width, minWidth, maxWidth)

{-| The field by class, in running order, and the page's one place for picking
the cars the middle of it is given over to.

It is not a column of the strip: never carried, stepped or closed. The page
gives it its width, which the reader drags between `minWidth` and `maxWidth`;
surnames are drawn once the panel stands wide enough for them to fit.

@docs view, width, minWidth, maxWidth

-}

import Html exposing (Html, button, div, li, text)
import Html.Attributes exposing (attribute, class, style, title)
import Html.Events exposing (onClick)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Motorsport.Driver as Driver
import Motorsport.Race.Car exposing (CarNumber, Metadata)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Status as Status
import Motorsport.Wec.Class as Class exposing (Class)
import UI.Shadcn.Card as Card
import View.CarNumberBadge as CarNumberBadge


{-| One card around the whole panel; the classes are sections of it, not
cards of their own.

A row is marked when its car is in `withColumns`. Clicking an unmarked row
hands `onSelect` the car it names; a marked row does nothing, its column
being closed from the column itself.

`onSelect` is held as it is handed over, so pass a message constructor: the
rows are thunked, and a lambda or a composition built afresh on each render
compares unequal and draws every one of them again.

-}
view :
    { onSelect : CarNumber -> msg
    , withColumns : List CarNumber
    , width : Float
    }
    -> Snapshot
    -> Html msg
view config snapshot =
    let
        showNames =
            config.width >= namesWidth
    in
    Card.card
        -- Which the visual tests locate the standings by.
        [ attribute "data-live-standings" ""
        , style "width" (px config.width)
        ]
        [ Card.header []
            [ Card.title [] [ text "Standings" ] ]
        , div [ class "flex-1 min-h-0 grid grid-rows-[minmax(0,1fr)]" ]
            [ Card.content []
                [ div [ class "h-full grid auto-rows-[minmax(0,1fr)] gap-y-3" ]
                    (Snapshot.toClassList snapshot
                        |> List.map (classSection config.onSelect config.withColumns showNames)
                    )
                ]
            ]
        ]


{-| The width the panel arrives at: the row with its surname, the badge and
the position, plus the card's padding.
-}
width : Float
width =
    218


{-| The narrowest it can be dragged to: the widest thing a nameless row
still draws -- its position and its badge -- plus the card's padding.
-}
minWidth : Float
minWidth =
    130


{-| The widest it can be dragged to. Past this the panel would crowd the
strip out of the page before the reader could drag it back.
-}
maxWidth : Float
maxWidth =
    420


{-| The width a surname starts to fit at: `minWidth` plus room for the
name itself.
-}
namesWidth : Float
namesWidth =
    170


px : Float -> String
px n =
    String.fromFloat n ++ "px"


{-| The class's two lines: where its name stands, and the cars under it.

Each class takes an equal share of the panel's height and scrolls its own
cars within it, so every class is always on show at once.

-}
classSection :
    (CarNumber -> msg)
    -> List CarNumber
    -> Bool
    -> ( Class, List CarAt )
    -> Html msg
classSection onSelect withColumns showNames ( class_, cars ) =
    div [ class "grid grid-rows-[auto_minmax(0,1fr)] min-h-0" ]
        [ div
            [ class "flex items-center gap-x-[0.5em] pb-1 text-[10px] font-bold before:block before:content-[''] before:w-[0.2em] before:h-[1.2em] before:rounded-[2px] before:[background-color:var(--class-color)]"
            , attribute "style" ("--class-color: " ++ Class.toColor class_ ++ ";")
            ]
            [ text (Class.toString class_) ]
        , Keyed.node "ul"
            [ class "flex flex-col text-sm overflow-y-auto" ]
            (cars
                |> List.map
                    (\item ->
                        ( item.metadata.carNumber
                        , Lazy.lazy7 carRow
                            onSelect
                            item.metadata
                            item.standing.position
                            (Driver.toSurname item.currentDriver)
                            (item.status == Status.InPit)
                            (List.member item.metadata.carNumber withColumns)
                            showNames
                        )
                    )
            )
        ]


{-| Takes the row's pieces rather than the `CarAt` they are read off. A thunk's
arguments are compared by `===`, and a `CarAt` is built afresh at every clock;
the metadata is the car's own, which the race holds still, and the rest are
primitives. `onSelect` is the caller's own tag, which is held still too.

The row reads as the number of the car it picks rather than as its three
columns, which are the position and driver the reader already has in front of
them.

-}
carRow : (CarNumber -> msg) -> Metadata -> Int -> String -> Bool -> Bool -> Bool -> Html msg
carRow onSelect metadata position driverSurname isInPit hasColumn showNames =
    li []
        [ button
            ([ attribute "aria-label" ("Car #" ++ metadata.carNumber)
             , attribute "aria-pressed"
                (if hasColumn then
                    "true"

                 else
                    "false"
                )
             , class
                ("relative w-full p-0.5 grid "
                    ++ (if showNames then
                            "grid-cols-[20px_auto_1fr]"

                        else
                            "grid-cols-[20px_auto]"
                       )
                    ++ " items-center gap-2 text-left [word-break:break-word] rounded transition-colors"
                )
             ]
                ++ (if hasColumn then
                        -- The car's own colour, thinned enough to write on.
                        [ style "background-color"
                            ("color-mix(in oklch, " ++ metadata.manufacturer.color ++ " 25%, transparent)")
                        ]

                    else
                        [ onClick (onSelect metadata.carNumber)
                        , class "cursor-pointer hover:bg-accent/40"
                        ]
                   )
            )
            [ div [ class "text-center text-xs" ] [ text (String.fromInt position) ]
            , CarNumberBadge.viewRow metadata
            , if showNames then
                div [ class "text-xs" ] [ text driverSurname ]

              else
                text ""
            , if isInPit then
                div
                    [ class "absolute right-1 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full border border-border flex items-center justify-center text-white text-[9px] font-bold bg-card" ]
                    [ text "P" ]

              else
                text ""
            ]
        ]
