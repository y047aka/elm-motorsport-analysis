module View.LiveStandings exposing (view, width, minWidth, maxWidth)

{-| The field by class, in running order, and the page's one place for picking
the cars the middle of it is given over to.

It is not a column of the strip: never carried, stepped or closed. The page
gives it its width, which the reader drags between `minWidth` and `maxWidth`;
the row gains information as the panel widens — surnames, then the interval to
the car ahead, then the last lap, the lap running, the car's best, the laps
completed and the places moved, the same readings the `Leaderboard` prints in
its own columns. Once the numbers arrive a header row above the classes names
each column.

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
import Motorsport.Leaderboard as Leaderboard
import Motorsport.Position exposing (Position)
import Motorsport.Race.Car exposing (CarNumber, Metadata)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Status as Status
import Motorsport.Wec.Class as Class exposing (Class)
import UI.Shadcn.Card as Card
import View.CarNumberBadge as CarNumberBadge


{-| What the panel is given: the tag for picking a car, the cars that already
have a column of their own, the width the page stands it at, and where each
car started — the grid place the moved column counts from, which a `CarAt`
does not hold and only the round's entries know.
-}
type alias Config msg =
    { onSelect : CarNumber -> msg
    , withColumns : List CarNumber
    , width : Float
    , startPosition : CarNumber -> Maybe Position
    }


{-| One card around the whole panel; the classes are sections of it, not
cards of their own.

A row is marked when its car is in `withColumns`. Clicking an unmarked row
hands `onSelect` the car it names; a marked row does nothing, its column
being closed from the column itself.

`onSelect` is held as it is handed over, so pass a message constructor: the
rows are thunked, and a lambda or a composition built afresh on each render
compares unequal and draws every one of them again.

-}
view : Config msg -> Snapshot -> Html msg
view config snapshot =
    let
        stage =
            stageFor config.width

        sections =
            div [ class "h-full grid auto-rows-[minmax(0,1fr)] gap-y-3" ]
                (Snapshot.toClassList snapshot
                    |> List.map (classSection config stage)
                )
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
                [ if shows Intervals stage then
                    div [ class "h-full grid grid-rows-[auto_minmax(0,1fr)] gap-y-1" ]
                        [ headerRow stage, sections ]

                  else
                    sections
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
    620


{-| How much a row shows at a given panel width. Each stage shows what came
before it; which width each arrives at is the constants below.
-}
type Stage
    = Numbers
    | Names
    | Intervals
    | LastLaps
    | Running
    | Bests
    | Laps
    | Moves


rank : Stage -> Int
rank stage =
    case stage of
        Numbers ->
            0

        Names ->
            1

        Intervals ->
            2

        LastLaps ->
            3

        Running ->
            4

        Bests ->
            5

        Laps ->
            6

        Moves ->
            7


{-| `shows column stage` — does this stage carry that column's header and
text? A stage carries every column of every stage before it.
-}
shows : Stage -> Stage -> Bool
shows column stage =
    rank stage >= rank column


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


{-| The width the car's best lap starts to fit at.
-}
bestWidth : Float
bestWidth =
    475


{-| The width the laps completed start to fit at.
-}
lapsWidth : Float
lapsWidth =
    525


{-| The width the places moved start to fit at.
-}
movesWidth : Float
movesWidth =
    570


stageFor : Float -> Stage
stageFor panelWidth =
    if panelWidth >= movesWidth then
        Moves

    else if panelWidth >= lapsWidth then
        Laps

    else if panelWidth >= bestWidth then
        Bests

    else if panelWidth >= runningWidth then
        Running

    else if panelWidth >= lastLapWidth then
        LastLaps

    else if panelWidth >= intervalWidth then
        Intervals

    else if panelWidth >= namesWidth then
        Names

    else
        Numbers


px : Float -> String
px n =
    String.fromFloat n ++ "px"


{-| What each column is, above the classes. The container keeps the text size
the rows carry — `text-sm` — because the track widths are in `em` and would
otherwise measure against the labels' own 10px font and land each column
beside its text. The labels are the same words the `Leaderboard` prints over
its own columns, cut short for the narrow tracks: the interval to the car
ahead is AHEAD, the running clock is CURRENT.

The header appears with the first column a reader cannot read off the panel
itself, at `intervalWidth`.

-}
headerRow : Stage -> Html msg
headerRow stage =
    div
        [ class ("grid " ++ gridCols stage ++ " items-center gap-2 px-0.5 pb-1") ]
        [ label "text-center" "Pos"
        , label "text-center" "#"
        , if shows Names stage then
            label "" "Driver"

          else
            text ""
        , if shows Intervals stage then
            label "text-right" "Ahead"

          else
            text ""
        , if shows LastLaps stage then
            label "text-right" "Last"

          else
            text ""
        , if shows Running stage then
            label "text-right" "Current"

          else
            text ""
        , if shows Bests stage then
            label "text-right" "Best"

          else
            text ""
        , if shows Laps stage then
            label "text-right" "Laps"

          else
            text ""
        , if shows Moves stage then
            label "text-right" "Move"

          else
            text ""
        ]


label : String -> String -> Html msg
label align word =
    div [ class ("text-[10px] font-bold uppercase text-muted-foreground " ++ align) ]
        [ text word ]


{-| The class's two lines: where its name stands, and the cars under it.

Each class takes an equal share of the panel's height and scrolls its own
cars within it, so every class is always on show at once.

-}
classSection :
    Config msg
    -> Stage
    -> ( Class, List CarAt )
    -> Html msg
classSection config stage ( class_, cars ) =
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
                        , Lazy.lazy (carRow config.onSelect) (row stage config.withColumns config.startPosition item)
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
    , best : String
    , bestColor : String
    , laps : String
    , movement : { startPosition : Maybe Position, position : Position }
    }


row : Stage -> List CarNumber -> (CarNumber -> Maybe Position) -> CarAt -> Row
row stage withColumns startPosition item =
    let
        lastLapTime =
            case item.lastLap of
                Snapshot.Completed { rated } ->
                    Leaderboard.ratedTime rated

                Snapshot.NoLapYet ->
                    Leaderboard.ratedTime Nothing

        ( running, runningColor ) =
            if Status.hasRetired item.status then
                ( "-", "" )

            else
                ( Duration.toStringToTenths item.currentLap.elapsed, Performance.textColorOf item.currentLap.performance )

        bestTime =
            Leaderboard.ratedTime item.bestLap
    in
    { stage = stage
    , metadata = item.metadata
    , position = item.standing.position
    , surname = Driver.toSurname item.currentDriver
    , isInPit = item.status == Status.InPit
    , hasColumn = List.member item.metadata.carNumber withColumns
    , interval =
        if shows Intervals stage then
            Gap.toString item.standing.intervalToAhead

        else
            ""
    , lastLap =
        if shows LastLaps stage then
            lastLapTime.text

        else
            ""
    , lastLapColor =
        if shows LastLaps stage then
            lastLapTime.color

        else
            ""
    , running =
        if shows Running stage then
            running

        else
            ""
    , runningColor =
        if shows Running stage then
            runningColor

        else
            ""
    , best =
        if shows Bests stage then
            bestTime.text

        else
            ""
    , bestColor =
        if shows Bests stage then
            bestTime.color

        else
            ""
    , laps =
        if shows Laps stage then
            String.fromInt item.standing.lapsCompleted

        else
            ""
    , movement =
        -- The grid place arrives by car number rather than from the `CarAt`,
        -- which does not hold one; unknown reads as a place held.
        { startPosition = startPosition item.metadata.carNumber
        , position = item.standing.position
        }
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
                ++ (if r.isInPit && shows Intervals r.stage then
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
            , if shows Names r.stage then
                div [ class "text-xs" ] [ text r.surname ]

              else
                text ""
            , if shows Intervals r.stage then
                div [ class "text-xs text-right tabular-nums text-muted-foreground" ] [ text r.interval ]

              else
                text ""
            , if shows LastLaps r.stage then
                div [ class "text-xs text-right tabular-nums", style "color" r.lastLapColor ] [ text r.lastLap ]

              else
                text ""
            , if shows Running r.stage then
                div [ class "text-xs text-right tabular-nums", style "color" r.runningColor ] [ text r.running ]

              else
                text ""
            , if shows Bests r.stage then
                div [ class "text-xs text-right tabular-nums", style "color" r.bestColor ] [ text r.best ]

              else
                text ""
            , if shows Laps r.stage then
                div [ class "text-xs text-right tabular-nums" ] [ text r.laps ]

              else
                text ""
            , if shows Moves r.stage then
                div [ class "text-xs text-center tabular-nums" ] [ Leaderboard.viewPositionChangeInline r.movement ]

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

Each track list is written out whole rather than assembled from the stage:
Tailwind extracts class names from source text, so a `grid-cols-[...]` that
only exists at runtime is never in the stylesheet and the row falls back to
one track per child.

-}
gridCols : Stage -> String
gridCols stage =
    case stage of
        Numbers ->
            "grid-cols-[20px_auto]"

        Names ->
            "grid-cols-[20px_auto_1fr]"

        Intervals ->
            "grid-cols-[20px_auto_1fr_4.5em]"

        LastLaps ->
            "grid-cols-[20px_auto_1fr_4.5em_5em]"

        Running ->
            "grid-cols-[20px_auto_1fr_4.5em_5em_5em]"

        Bests ->
            "grid-cols-[20px_auto_1fr_4.5em_5em_5em_5em]"

        Laps ->
            "grid-cols-[20px_auto_1fr_4.5em_5em_5em_5em_3em]"

        Moves ->
            "grid-cols-[20px_auto_1fr_4.5em_5em_5em_5em_3em_2.5em]"
