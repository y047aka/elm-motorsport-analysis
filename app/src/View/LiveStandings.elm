module View.LiveStandings exposing (view, width, minWidth, maxWidth)

{-| The field by class, in running order, and the page's one place for picking
the cars the middle of it is given over to.

It is not a column of the strip: never carried, stepped or closed. The page
gives it its width, which the reader drags between `minWidth` and `maxWidth`;
the row gains information as the panel widens — surnames, then the interval to
the car ahead, then the last lap, then the lap running, the same readings the
`Leaderboard` prints in its own columns.

@docs view, width, minWidth, maxWidth

-}

import Html exposing (Html, button, div, li, text)
import Html.Attributes exposing (attribute, class, style, title)
import Html.Events exposing (onClick)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Lap.Performance as Performance
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
        stage =
            stageFor config.width
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
                        |> List.map (classSection config.onSelect config.withColumns stage)
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


{-| How much a row shows at a given panel width. Each stage shows what came
before it; which width each arrives at is the four constants below.
-}
type Stage
    = Numbers
    | Names
    | Intervals
    | LastLaps
    | Running


{-| The width a surname starts to fit at: `minWidth` plus room for the
name itself.
-}
namesWidth : Float
namesWidth =
    170


{-| The width the interval to the car ahead starts to fit at.
-}
intervalWidth : Float
intervalWidth =
    230


{-| The width the last lap starts to fit at.
-}
lastLapWidth : Float
lastLapWidth =
    315


{-| The width the running lap starts to fit at.
-}
runningWidth : Float
runningWidth =
    395


stageFor : Float -> Stage
stageFor panelWidth =
    if panelWidth >= runningWidth then
        Running

    else if panelWidth >= lastLapWidth then
        LastLaps

    else if panelWidth >= intervalWidth then
        Intervals

    else if panelWidth >= namesWidth then
        Names

    else
        Numbers


showsNames : Stage -> Bool
showsNames stage =
    stage /= Numbers


showsInterval : Stage -> Bool
showsInterval stage =
    stage == Intervals || stage == LastLaps || stage == Running


showsLastLap : Stage -> Bool
showsLastLap stage =
    stage == LastLaps || stage == Running


showsRunning : Stage -> Bool
showsRunning stage =
    stage == Running


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
    -> Stage
    -> ( Class, List CarAt )
    -> Html msg
classSection onSelect withColumns stage ( class_, cars ) =
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
                        , Lazy.lazy (carRow onSelect) (row stage withColumns item)
                        )
                    )
            )
        ]


{-| What a row holds, cut to the stage: a column the stage does not show
carries no text for it, so a row whose hidden columns are moving still
compares equal and is not drawn again.
-}
type alias Row =
    { stage : Stage
    , metadata : Metadata
    , position : Int
    , surname : String
    , isInPit : Bool
    , hasColumn : Bool
    , interval : String
    , lastLap : String
    , lastLapColor : String
    , running : String
    , runningColor : String
    }


row : Stage -> List CarNumber -> CarAt -> Row
row stage withColumns item =
    let
        ( lastLap, lastLapColor ) =
            case item.lastLap of
                Snapshot.Completed { rated } ->
                    case rated of
                        Just rated_ ->
                            ( Duration.toString rated_.time, Performance.textColorOf rated_.performance )

                        Nothing ->
                            ( "-", "" )

                Snapshot.NoLapYet ->
                    ( "-", "" )

        ( running, runningColor ) =
            if Status.hasRetired item.status then
                ( "-", "" )

            else
                ( Duration.toStringToTenths item.currentLap.elapsed, Performance.textColorOf item.currentLap.performance )
    in
    { stage = stage
    , metadata = item.metadata
    , position = item.standing.position
    , surname = Driver.toSurname item.currentDriver
    , isInPit = item.status == Status.InPit
    , hasColumn = List.member item.metadata.carNumber withColumns
    , interval =
        if showsInterval stage then
            Gap.toString item.standing.intervalToAhead

        else
            ""
    , lastLap =
        if showsLastLap stage then
            lastLap

        else
            ""
    , lastLapColor =
        if showsLastLap stage then
            lastLapColor

        else
            ""
    , running =
        if showsRunning stage then
            running

        else
            ""
    , runningColor =
        if showsRunning stage then
            runningColor

        else
            ""
    }


{-| The row's pieces, read off the `CarAt` by `row` rather than passed to this
alongside it. A thunk's arguments are compared by `===`, and a `CarAt` is
built afresh at every clock; the metadata is the car's own, which the race
holds still, and the rest are strings and flags compared by value. `onSelect`
is the caller's own tag, which is held still too.

The row reads as the number of the car it picks rather than as its columns,
which are the position and driver the reader already has in front of them.

-}
carRow : (CarNumber -> msg) -> Row -> Html msg
carRow onSelect r =
    li []
        [ button
            ([ attribute "aria-label" ("Car #" ++ r.metadata.carNumber)
             , attribute "aria-pressed"
                (if r.hasColumn then
                    "true"

                 else
                    "false"
                )
             , class
                ("relative w-full p-0.5 grid "
                    ++ gridCols r.stage
                    ++ " items-center gap-2 text-left [word-break:break-word] rounded transition-colors"
                )
             ]
                ++ (if r.isInPit && showsInterval r.stage then
                        -- The pit mark floats at the row's right edge, where
                        -- a time column now ends; the room is its own.
                        [ class "pr-6" ]

                    else
                        []
                   )
                ++ (if r.hasColumn then
                        -- The car's own colour, thinned enough to write on.
                        [ style "background-color"
                            ("color-mix(in oklch, " ++ r.metadata.manufacturer.color ++ " 25%, transparent)")
                        ]

                    else
                        [ onClick (onSelect r.metadata.carNumber)
                        , class "cursor-pointer hover:bg-accent/40"
                        ]
                   )
            )
            [ div [ class "text-center text-xs" ] [ text (String.fromInt r.position) ]
            , CarNumberBadge.viewRow r.metadata
            , if showsNames r.stage then
                div [ class "text-xs" ] [ text r.surname ]

              else
                text ""
            , if showsInterval r.stage then
                div [ class "text-xs text-right tabular-nums text-muted-foreground" ] [ text r.interval ]

              else
                text ""
            , if showsLastLap r.stage then
                div [ class "text-xs text-right tabular-nums", style "color" r.lastLapColor ] [ text r.lastLap ]

              else
                text ""
            , if showsRunning r.stage then
                div [ class "text-xs text-right tabular-nums", style "color" r.runningColor ] [ text r.running ]

              else
                text ""
            , if r.isInPit then
                div
                    [ class "absolute right-1 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full border border-border flex items-center justify-center text-white text-[9px] font-bold bg-card" ]
                    [ text "P" ]

              else
                text ""
            ]
        ]


{-| The row's tracks: position and badge always, then one per column the
stage shows. The widths are the widest each column's text prints at —
`Gap.toString` never longer than '+ 9 Laps', a lap time never longer than
'9:99:99.999'.
-}
gridCols : Stage -> String
gridCols stage =
    "grid-cols-[20px_auto"
        ++ (if showsNames stage then
                " 1fr"

            else
                ""
           )
        ++ (if showsInterval stage then
                " 4.5em"

            else
                ""
           )
        ++ (if showsLastLap stage then
                " 5em"

            else
                ""
           )
        ++ (if showsRunning stage then
                " 5em"

            else
                ""
           )
        ++ "]"
