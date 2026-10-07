module View.LiveStandings exposing (view, width, minWidth, maxWidth)

{-| The field by class, in running order, and the page's one place for picking
the cars the middle of it is given over to.

It is not a column of the strip: never carried, stepped or closed. The page
gives it its width, which the reader drags between `minWidth` and `maxWidth`.

What a row shows is held in one table, `columns`, which is the single place
the width a column arrives at, the track it takes and the word over it are
written. The rows and the header above them both draw from it.

The two modules split the work by who decides it: `Motorsport.Leaderboard`
draws a reading — the rated time, the moved arrow, the sector strip — and
this panel decides which readings it carries, in what order, at what width.
A row that wants a lap time drawn asks that module, and the module never
hears about widths.

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
        sections =
            div [ class "h-full grid auto-rows-[minmax(0,1fr)] gap-y-3" ]
                (Snapshot.toClassList snapshot
                    |> List.map (classSection config)
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
                [ if fits config.width Ahead then
                    div [ class "h-full grid grid-rows-[auto_minmax(0,1fr)] gap-y-1" ]
                        [ headerRow config.width, sections ]

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


{-| A data column of the row, in the order they stand after the position and
the badge — which are not columns and are always drawn.

Each column says once what the whole panel then says about it: `at`, the
width of panel it fits in, `track`, the grid track it takes, `label`, the word
over it, and `align`, which both the label and the cells line up by.

-}
type Column
    = Driver
    | Ahead
    | Last
    | Current
    | Best
    | Laps
    | Move


type alias Spec =
    { label : String
    , at : Float
    , track : String
    , align : String
    }


columnSpec : Column -> Spec
columnSpec column =
    case column of
        Driver ->
            { label = "Driver", at = 170, track = "1fr", align = "" }

        Ahead ->
            { label = "Ahead", at = 230, track = "4.5em", align = "text-right" }

        Last ->
            { label = "Last", at = 315, track = "5em", align = "text-right" }

        Current ->
            { label = "Current", at = 395, track = "5em", align = "text-right" }

        Best ->
            { label = "Best", at = 475, track = "5em", align = "text-right" }

        Laps ->
            { label = "Laps", at = 525, track = "3em", align = "text-right" }

        Move ->
            { label = "Move", at = 570, track = "2.5em", align = "text-center" }


{-| Every column, in row order.
-}
columns : List Column
columns =
    [ Driver, Ahead, Last, Current, Best, Laps, Move ]


{-| Does this column fit a panel of this width?
-}
fits : Float -> Column -> Bool
fits panelWidth column =
    panelWidth >= (columnSpec column).at


visible : Float -> List Column
visible panelWidth =
    List.filter (fits panelWidth) columns


{-| The row's tracks as a `grid-template-columns` value: the position and the
badge, then one per visible column. The header stands on the same value, which
is what keeps a label over its column.

The tracks go on as a style attribute rather than as a `grid-cols-[...]`
class: Tailwind extracts class names from source text only, so a class
assembled from the table above ships no rule at all — which is exactly how
this panel once rendered with one track per child.

-}
gridTracks : Float -> String
gridTracks panelWidth =
    "20px auto"
        ++ String.concat (List.map (\column -> " " ++ (columnSpec column).track) (visible panelWidth))


px : Float -> String
px n =
    String.fromFloat n ++ "px"


{-| What each column is, above the classes. It appears with the first column
of measured time, `Ahead`; a panel of position and badge and name needs no
label.

The container keeps the text size the rows carry — `text-sm` — because the
tracks are in `em` and would otherwise measure against the labels' own 10px
font and land each column beside its text. The labels are the `Leaderboard`'s
own words, cut short for the narrow tracks: the interval to the car ahead is
Ahead, the running clock is Current.

-}
headerRow : Float -> Html msg
headerRow panelWidth =
    div
        [ class "grid items-center gap-2 px-0.5 pb-1"
        , style "grid-template-columns" (gridTracks panelWidth)
        ]
        ([ label "text-center" "Pos"
         , label "text-center" "#"
         ]
            ++ List.map
                (\column ->
                    let
                        spec =
                            columnSpec column
                    in
                    label spec.align spec.label
                )
                (visible panelWidth)
        )


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
    -> ( Class, List CarAt )
    -> Html msg
classSection config ( class_, cars ) =
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
                        , Lazy.lazy (carRow config.onSelect) (row config item)
                        )
                    )
            )
        ]


{-| Every reading of the car, read off the `CarAt` once per frame; `cell`
picks which of them the row's width shows.
-}
type alias Row =
    { width : Float
    , metadata : Metadata
    , position : Int
    , isInPit : Bool
    , hasColumn : Bool
    , driver : String
    , ahead : String
    , last : String
    , lastColor : String
    , current : String
    , currentColor : String
    , best : String
    , bestColor : String
    , laps : String
    , move : { startPosition : Maybe Position, position : Position }
    }


row : Config msg -> CarAt -> Row
row config item =
    let
        lastLapTime =
            case item.lastLap of
                Snapshot.Completed { rated } ->
                    Leaderboard.ratedTime rated

                Snapshot.NoLapYet ->
                    Leaderboard.ratedTime Nothing

        bestTime =
            Leaderboard.ratedTime item.bestLap

        ( current, currentColor ) =
            if Status.hasRetired item.status then
                ( "-", "" )

            else
                ( Duration.toStringToTenths item.currentLap.elapsed, Performance.textColorOf item.currentLap.performance )
    in
    { width = config.width
    , metadata = item.metadata
    , position = item.standing.position
    , isInPit = item.status == Status.InPit
    , hasColumn = List.member item.metadata.carNumber config.withColumns
    , driver = Driver.toSurname item.currentDriver
    , ahead = Gap.toString item.standing.intervalToAhead
    , last = lastLapTime.text
    , lastColor = lastLapTime.color
    , current = current
    , currentColor = currentColor
    , best = bestTime.text
    , bestColor = bestTime.color
    , laps = String.fromInt item.standing.lapsCompleted
    , move =
        -- The grid place arrives by car number rather than from the `CarAt`,
        -- which does not hold one; unknown reads as a place held.
        { startPosition = config.startPosition item.metadata.carNumber
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
             , class "relative w-full p-0.5 grid items-center gap-2 text-left [word-break:break-word] rounded transition-colors"
             , style "grid-template-columns" (gridTracks r.width)
             ]
                ++ (if r.isInPit && fits r.width Ahead then
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
            ([ div [ class "text-center text-xs" ] [ text (String.fromInt r.position) ]
             , CarNumberBadge.viewRow r.metadata
             ]
                ++ List.map (cell r) (visible r.width)
                ++ [ if r.isInPit then
                        div
                            [ class "absolute right-1 top-1/2 -translate-y-1/2 w-4 h-4 rounded-full border border-border flex items-center justify-center text-white text-[9px] font-bold bg-card" ]
                            [ text "P" ]

                     else
                        text ""
                   ]
            )
        ]


{-| One visible column's cell. The tracks and the cells both walk
`visible width`, so which cell stands in which track is held by construction,
and each cell lines itself up by the same `align` its label does.
-}
cell : Row -> Column -> Html msg
cell r column =
    let
        spec =
            columnSpec column

        numeral =
            "text-xs tabular-nums " ++ spec.align

        timed time color =
            div [ class numeral, style "color" color ] [ text time ]
    in
    case column of
        Driver ->
            div [ class "text-xs" ] [ text r.driver ]

        Ahead ->
            div [ class (numeral ++ " text-muted-foreground") ] [ text r.ahead ]

        Last ->
            timed r.last r.lastColor

        Current ->
            timed r.current r.currentColor

        Best ->
            timed r.best r.bestColor

        Laps ->
            div [ class numeral ] [ text r.laps ]

        Move ->
            div [ class numeral ] [ Leaderboard.viewPositionChangeInline r.move ]
