module View.LiveStandings exposing (view, width, minWidth, maxWidth)

{-| The field by class, in running order, and the page's one place for picking
the cars the middle of it is given over to.

It is not a column of the strip: never carried, stepped or closed. The page
gives it its width, which the reader drags between `minWidth` and `maxWidth`.

The width a column arrives at, the track it takes and the word over it are
written in one table, `columns`; the rows and the header above them both draw
from it. How a reading looks is the `Leaderboard`'s, which never hears about
widths; which readings this panel carries, and at what width, is here.

@docs view, width, minWidth, maxWidth

-}

import Html exposing (Html, button, div, li, span, text)
import Html.Attributes exposing (attribute, class, style, title)
import Html.Events exposing (onClick)
import Html.Keyed as Keyed
import Html.Lazy as Lazy
import Motorsport.Analysis.Deployment as Deployment exposing (Deployment)
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Lap.Performance as Performance
import Motorsport.Leaderboard as Leaderboard
import Motorsport.Position exposing (Position)
import Motorsport.Race.Car exposing (CarNumber, Metadata)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Speed exposing (Speed)
import Motorsport.Status as Status
import Motorsport.Wec.Class as Class exposing (Class)
import UI.Shadcn.Card as Card
import View.CarNumberBadge as CarNumberBadge
import View.ClassMark as ClassMark
import View.DeploymentBar as DeploymentBar
import View.SectorPie as SectorPie


{-| What the panel is given: the tag for picking a car, the cars that already
have a column of their own, the width the page stands it at, and where each
car started — the grid place the moved column counts from, which a `CarAt`
does not hold and only the round's entries know.

`openColumn` is asked of every class: a message for the class's own column where
the strip has none, and nothing where the column is standing. See
[`View.ClassColumn`](View-ClassColumn).

`deployments` is the round's own reading of what each car is doing with its speed,
taken once as the round loads; the row looks its car up in it at however far the
clock has got, which is why the standings can show a reading that says what the car
has done so far rather than what it does later.

-}
type alias Config msg =
    { onSelect : CarNumber -> msg
    , withColumns : List CarNumber
    , openColumn : Class -> Maybe msg
    , width : Float
    , startPosition : CarNumber -> Maybe Position
    , deployments : Deployment.Table
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


{-| The width the panel arrives at: the row with its initial and surname,
the badge and the position, plus the card's padding.
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
    780


{-| A data column of the row. `columns` is the order they are drawn in; the
thresholds stand in `columnSpec`. `align` is read by both the label and the
cells, which is what keeps them lined up.
-}
type Column
    = Driver
    | Move
    | Ahead
    | Last
    | Pie
    | Current
    | Best
    | Laps
    | Deploy


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

        Move ->
            { label = "Move", at = 150, track = "2.5em", align = "text-center" }

        Ahead ->
            { label = "Ahead", at = 270, track = "5em", align = "text-right" }

        Last ->
            { label = "Last", at = 390, track = "5em", align = "text-right" }

        Pie ->
            { label = "Lap", at = 340, track = String.fromFloat SectorPie.pieSize ++ "px", align = "" }

        Current ->
            { label = "Current", at = 470, track = "5em", align = "text-right" }

        Best ->
            { label = "Best", at = 560, track = "5em", align = "text-right" }

        Laps ->
            { label = "Laps", at = 620, track = "3em", align = "text-right" }

        Deploy ->
            { label = "Deploy", at = 700, track = String.fromFloat DeploymentBar.width ++ "px", align = "" }


{-| Every column, in row order.
A column's `at` is the panel width from which it stands, in its own place in
the row. The thresholds follow the readings' worth and not this order, so a
widening panel may bring a left column in after one that stands to its
right -- that is the design, not an oversight to fix.
-}
columns : List Column
columns =
    [ Driver, Ahead, Laps, Current, Pie, Last, Best, Deploy, Move ]


{-| Does this column fit a panel of this width?
-}
fits : Float -> Column -> Bool
fits panelWidth column =
    panelWidth >= (columnSpec column).at


visible : Float -> List Column
visible panelWidth =
    List.filter (fits panelWidth) columns


{-| The row's tracks as a `grid-template-columns` value: the position, the
badge, and one per visible column.
The header stands on the same value, which is what keeps a label over its
column and every row's columns lined up.

The tracks go on as a style attribute rather than as a `grid-cols-[...]`
class: Tailwind extracts class names from source text only, so a class
assembled from the table above ships no rule at all, and the row falls back
to one track per child.

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
        [ class "grid items-center gap-2 px-0.5 pb-1 text-sm"
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
        [ classLine config class_
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


{-| Where the class's name stands at the head of its section of the standings.

A class with a column of its own is a heading and nothing else, so the
standings read the same however the strip is standing. A class whose column
the reader took away is the press that puts it back.

-}
classLine : Config msg -> Class -> Html msg
classLine config class_ =
    case config.openColumn class_ of
        Nothing ->
            div [ class "pb-1" ] [ ClassMark.name class_ ]

        Just msg ->
            button
                [ attribute "aria-label" ("Open the " ++ Class.toString class_ ++ " column")
                , title ("Open the " ++ Class.toString class_ ++ " column")
                , onClick msg
                , class "flex items-center gap-x-1 w-full cursor-pointer rounded-[3px] px-0.5 py-0.5 text-left transition-colors hover:bg-accent/40"
                ]
                [ ClassMark.name class_, plus ]


{-| The mark that a class's column is away and one press puts it back on the
strip.
-}
plus : Html msg
plus =
    span [ class "ms-auto text-[11px] leading-none text-muted-foreground" ] [ text "+" ]


{-| Every reading of the car, whatever the row's width ends up showing;
`cell` picks.
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
    , sectorSlots : List ( String, Float )
    , deployment : Maybe Deployment
    , deploymentScale : Maybe Speed
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
    , driver = Driver.toInitialAndSurname item.currentDriver
    , ahead = Gap.toString item.standing.intervalToAhead
    , last = lastLapTime.text
    , lastColor = lastLapTime.color
    , current = current
    , currentColor = currentColor
    , best = bestTime.text
    , bestColor = bestTime.color
    , laps = String.fromInt item.standing.lapsCompleted
    , sectorSlots = SectorPie.slots item
    , deployment =
        Deployment.lookup item.metadata.carNumber item.standing.lapsCompleted config.deployments
    , deploymentScale =
        Deployment.spread item.metadata.class item.standing.lapsCompleted config.deployments
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
             , class "w-full p-0.5 grid items-center gap-2 text-left rounded transition-colors"
             , style "grid-template-columns" (gridTracks r.width)
             ]
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
            ([ positionCell r
             , CarNumberBadge.viewRow r.metadata
             ]
                ++ List.map (cell r) (visible r.width)
            )
        ]


positionCell : Row -> Html msg
positionCell r =
    if r.isInPit then
        div
            [ class "mx-auto w-4 h-4 rounded-full border border-border flex items-center justify-center text-white text-[9px] font-bold bg-card" ]
            [ text "P" ]

    else
        div [ class "text-center text-xs" ] [ text (String.fromInt r.position) ]


{-| One visible column's cell, aligned as its label is.
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
            div [ class "truncate text-xs", title r.driver ] [ text r.driver ]

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

        Pie ->
            div [ class "justify-self-center" ] [ SectorPie.pie r.sectorSlots ]

        Move ->
            div [ class numeral ] [ Leaderboard.viewPositionChangeInline r.move ]

        Deploy ->
            DeploymentBar.bar r.deployment r.deploymentScale
