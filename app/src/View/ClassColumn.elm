module View.ClassColumn exposing (Trace(..), view)

{-| One class of the field as a column of the strip: its cars in running order,
each measured against the class-mate ahead of it.

The standings to the left of the strip count the whole field; this counts one
class. Every reading is taken down the class rather than down the field, which is
what the field hides while a race is still sorting itself out: the interval is to
the class-mate ahead rather than to whoever is ahead, the reference lap is the
class's own fastest rather than the race's, and the cars are all the cars the
class has, leader first.

A row picks the car it names, whose own column opens beside this one, so a class
can be followed from its order here and from a car's detail at the same time.

Each row carries a curve of how the car is running underneath it -- the gap
out to the rivals either side of it, the spread of its own lap times, or the
lap times themselves -- and the reader picks which from the column's head.

The foot is the class's own pit board, and only when the lane has one of the
class: the tracker's board ruled with just these cars, saying who is being
served, who is driving away, and who climbed into the car.

@docs view

-}

import Html exposing (Html, button, div, img, text)
import Html.Attributes exposing (alt, attribute, class, src, style, title)
import Html.Events exposing (onClick)
import Html.Keyed as Keyed
import Motorsport.Analysis.Rivals as Rivals
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Race.Car exposing (CarNumber)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Status as Status exposing (Status)
import Motorsport.Wec.Class as Class exposing (Class)
import UI.Shadcn.Card as Card
import UI.Shadcn.ToggleGroup as ToggleGroup
import View.CarDetail.Header as Header
import View.CarNumberBadge as CarNumberBadge
import View.ClassMark as ClassMark
import View.PitLane as PitLane
import View.SectorAndLaps as SectorAndLaps


{-| What the column is given: the two ways a row answers a press -- the car has
no column and so is picked, or has one already and so the strip goes to it --
which cars have columns, and the corner controls every column carries.

`onSelect` and `onReveal` are held as they are handed over, so pass message
constructors: the rows are rebuilt on every frame of playback, and a lambda built
afresh per render rewrites every row of every class on every frame.

-}
type alias Config msg =
    { onSelect : CarNumber -> msg
    , onReveal : CarNumber -> msg
    , withColumns : List CarNumber
    , trace : Trace
    , onTrace : Trace -> msg
    , onClose : Maybe msg
    , grip : Maybe (Html msg)
    }


{-| The curve drawn under every car of the column: the gap out to the rivals
either side, the spread of the car's own lap times, or the lap times
themselves.
-}
type Trace
    = GapTrace
    | PaceTrace
    | LapsTrace


{-| The laps the class leader has completed, which is what every car's distance
is measured against.
-}
type alias Count =
    { lead : Int }


count : List CarAt -> Count
count cars =
    { lead =
        case cars of
            first :: _ ->
                first.standing.lapsCompleted

            _ ->
                0
    }


{-| The column. The class's name and its own fastest lap hold the head of the
card and the cars scroll under them, the way a car's panel scrolls under its
nameplate.

The visual tests locate the column by `data-class-column`, which carries the
class's name.

-}
view : Config msg -> Snapshot -> Class -> Html msg
view config snapshot class_ =
    let
        cars =
            Snapshot.inClass class_ snapshot

        -- Each car with the class-mate ahead of it, which is the car its gap is
        -- measured to. The head of the class is ahead of nobody, and until the
        -- class has completed a lap nobody is measured against anybody: the
        -- column is the starting grid.
        field =
            let
                ahead =
                    if counted.lead > 0 then
                        List.map Just cars

                    else
                        List.repeat (List.length cars) Nothing
            in
            List.map2 Tuple.pair (Nothing :: ahead) cars

        counted =
            count cars

        lane =
            List.filter (\car -> car.inLane /= Nothing) cars

        foot =
            if List.isEmpty lane then
                []

            else
                [ pitBoard lane ]
    in
    Card.card
        [ attribute "data-class-column" (Class.toString class_) ]
        [ div [ class "flex-1 min-h-0 grid grid-rows-[minmax(0,1fr)]" ]
            [ Card.content []
                [ div [ class (gridClass lane) ]
                    ([ head config class_ cars
                     , Keyed.node "div"
                        [ class "min-h-0 overflow-y-auto grid auto-rows-min content-start gap-y-px"
                        , attribute "data-class-rows" ""
                        ]
                        (rows config snapshot counted cars field)
                     ]
                        ++ foot
                    )
                ]
            ]
        ]


{-| The class's own pit board: the tracker's board ruled with just this class's.
-}
pitBoard : List CarAt -> Html msg
pitBoard lane =
    div [ class "min-h-0 max-h-40 overflow-y-auto border-t border-border pt-1" ]
        [ PitLane.board lane ]


{-| The standings hold their scroll; the board, when the lane has one of the
class, takes the line under them.
-}
gridClass : List CarAt -> String
gridClass lane =
    if List.isEmpty lane then
        "h-full min-h-0 grid grid-rows-[auto_minmax(0,1fr)] gap-y-1.5"

    else
        "h-full min-h-0 grid grid-rows-[auto_minmax(0,1fr)_auto] gap-y-1.5"


{-| The class, how many cars it has out, and the fastest lap the class has run.

The reference lap is the class's and not the race's: an LMGT3 car is race leader
nobody would call quick, and the lap every car of a class is chasing is one run
by one of them.

-}
head : Config msg -> Class -> List CarAt -> Html msg
head config class_ cars =
    div [ class "grid gap-y-1" ]
        [ div [ class "flex items-center gap-x-2" ]
            [ ClassMark.name class_
            , div [ class "ms-auto text-[10px] text-muted-foreground tabular-nums whitespace-nowrap" ]
                [ text (carCount cars) ]
            , traceChoice config
            , div [ class "flex items-start gap-x-1" ] (corner config)
            ]
        , reference cars
        ]


{-| The head's picker for the rows' curve: one press per column, and the
page holds which curve it asks for.
-}
traceChoice : Config msg -> Html msg
traceChoice config =
    ToggleGroup.view
        { items =
            [ { label = "Gap"
              , active = config.trace == GapTrace
              , disabled = False
              , onSelect = config.onTrace GapTrace
              }
            , { label = "Pace"
              , active = config.trace == PaceTrace
              , disabled = False
              , onSelect = config.onTrace PaceTrace
              }
            , { label = "Laps"
              , active = config.trace == LapsTrace
              , disabled = False
              , onSelect = config.onTrace LapsTrace
              }
            ]
        }
        [ class "shrink-0" ]


carCount : List CarAt -> String
carCount cars =
    String.fromInt (List.length cars)
        ++ (if List.length cars == 1 then
                " car"

            else
                " cars"
           )


{-| The fastest lap the class has run so far and the number of the car that ran
it -- nothing where the class has finished no timed lap yet, which is every class
for the first minutes of a race.
-}
reference : List CarAt -> Html msg
reference cars =
    div [ class "flex items-baseline gap-x-1.5 text-[10px] leading-none" ]
        ([ label "Fastest" ]
            ++ (case fastest cars of
                    Just ( time, holder ) ->
                        [ div [ class "tabular-nums" ] [ text (Duration.toString time) ]
                        , div [ class "text-muted-foreground" ] [ text ("#" ++ holder) ]
                        ]

                    Nothing ->
                        [ div [ class "text-muted-foreground" ] [ text "no timed lap" ] ]
               )
        )


fastest : List CarAt -> Maybe ( Duration, CarNumber )
fastest cars =
    cars
        |> List.filterMap (\car -> Maybe.map (\rated -> ( rated.time, car.metadata.carNumber )) car.bestLap)
        |> List.sortBy Tuple.first
        |> List.head


label : String -> Html msg
label word =
    div [ class "text-[9px] uppercase tracking-[0.03em] text-muted-foreground" ] [ text word ]


{-| The grip and the ✕, which the page supplies. A column standing alone has
neither, as elsewhere on the strip.
-}
corner : Config msg -> List (Html msg)
corner config =
    List.filterMap identity [ config.grip, Maybe.map Header.closeButton config.onClose ]



-- ROWS


{-| One car of the class, drawn on the car's own nameplate: a compact number
badge at the left, the driver over the team beside it, and the car itself side
on down the whole right edge of the row.

The readings -- class place and interval -- each hold a track of their own, so
each is a column down the class. The row draws no move at all: what a car has
gained or lost since the grid is the reading the standings beside the strip
make for the field, and measured in the class it would be a second ranking of
cars this column already ranks by the timing. The track a move would have cost
holds the car's photograph.

The ordinal is the class's, which is what this column is for: a car is 1st here
and 41st on the standings beside it, and both are true.

-}
row : Config msg -> Snapshot -> List CarAt -> ( Maybe CarAt, CarAt ) -> ( String, Html msg )
row config snapshot classCars ( ahead, item ) =
    let
        metadata =
            item.metadata

        picked =
            List.member metadata.carNumber config.withColumns
    in
    ( metadata.carNumber
    , button
        (rowButton config item picked ++ [ class rowClass ])
        [ ordinal item
        , div [ class "col-start-2 row-span-2 self-center" ] [ CarNumberBadge.viewCompact metadata ]
        , div [ class "col-start-3 min-w-0 truncate ps-1.5 text-[11px] font-semibold leading-[18px] tracking-tight", attribute "data-gives-way" "" ]
            [ text (Driver.toInitialAndSurname item.currentDriver) ]
        , gapAhead snapshot ahead item
        , now item
        , div [ class "col-start-3 row-start-2 min-w-0 self-center truncate ps-1.5 text-[11px] leading-[18px] text-muted-foreground", attribute "data-gives-way" "" ]
            [ text metadata.team ]
        , portrait item
        , rowTrace config.trace classCars snapshot item
        ]
    )


{-| The curve under the car, of whichever kind the column's head picks.

Gap: the car and the rival either side over the last stretch of laps, as
[`gapSparkline`](Motorsport-Chart-GapChart#gapSparkline) draws it. The gaps are
matched by lap number, so a lapped rival is about a lap of cumulative time
away at the same lap number and is clipped outside the band as an outlier
rather than flattening it.

Pace: the car's own racing laps as one curve on a lap-time scale of its own,
as [`sparkline`](Motorsport-Chart-LapTimeDistribution#sparkline) draws it, the
rivals not in it at all -- two classes on one lap-time axis flatten both. The
range spans the whole race the car has run: `Pace` clips its outliers against
the range it is given, so a recent window would measure the fence against the
stretch it is supposed to filter.

Laps: the lap the car is on, its sectors as a pie, beside the lap it just
completed, as [`view`](View-SectorAndLaps) draws them.
-}
rowTrace : Trace -> List CarAt -> Snapshot -> CarAt -> Html msg
rowTrace trace classCars snapshot item =
    let
        currentLap =
            item.standing.lapsCompleted

        history =
            Snapshot.lapHistory snapshot
    in
    div [ class "col-span-5 row-start-3", attribute "data-row-trace" (traceName trace) ]
        [ case trace of
            GapTrace ->
                GapChart.gapSparkline
                    { first = currentLap - recentLapCount, last = currentLap }
                    history
                    (Rivals.around classCars item)

            PaceTrace ->
                LapTimeDistribution.sparkline
                    { first = 1, last = currentLap }
                    history
                    item

            LapsTrace ->
                SectorAndLaps.view item
        ]


{-| The value `data-row-trace` carries, which the visual tests locate a row's
curve by.
-}
traceName : Trace -> String
traceName trace =
    case trace of
        GapTrace ->
            "gap"

        PaceTrace ->
            "pace"

        LapsTrace ->
            "laps"


{-| How many laps back the gap curve reaches: a row is a reading of the race as
it is running, not of the race.
-}
recentLapCount : Int
recentLapCount =
    20


{-| The car side on, as the car's own panel draws it, as tall
as the two lines together and against the right edge -- and nothing where the
round has no photograph for it, which is a missing row of `car-images.json`,
not a car off the field.
-}
portrait : CarAt -> Html msg
portrait item =
    case item.metadata.imageUrl of
        Just url ->
            img
                [ src url
                , alt (item.metadata.carNumber ++ " " ++ item.metadata.team)
                , class "col-start-5 row-span-2 self-center justify-self-end h-7 w-[5.25rem] object-contain"
                ]
                []

        Nothing ->
            text ""


{-| What every row of the class answers a press with and carries for the
reader who cannot see it: its name, its pressed state, and where the press
goes -- a car with a column already is revealed, not opened twice.
-}
rowButton : Config msg -> CarAt -> Bool -> List (Html.Attribute msg)
rowButton config item picked =
    [ attribute "aria-label" ("Car #" ++ item.metadata.carNumber ++ " in " ++ Class.toString item.metadata.class)
    , attribute "aria-pressed"
        (if picked then
            "true"

         else
            "false"
        )
    , title (item.metadata.team ++ " · " ++ Driver.toInitialAndSurname item.currentDriver)
    ]
        ++ (if picked then
                -- The same mark a row of the standings wears once its car is up.
                [ style "background-color"
                    ("color-mix(in oklch, " ++ item.metadata.manufacturer.color ++ " 25%, transparent)")
                , onClick (config.onReveal item.metadata.carNumber)
                ]

            else
                [ onClick (config.onSelect item.metadata.carNumber)
                , class "hover:bg-accent/40"
                ]
           )


{-| The class down the column, a rule wherever the classification moves to another
group. The first division a class makes is not visible in a gap read in seconds:
the cars above the rule are fighting the race and the ones below are finishing
their own.

Keyed by the car a rule starts at, which no other row can claim.

-}
rows : Config msg -> Snapshot -> Count -> List CarAt -> List ( Maybe CarAt, CarAt ) -> List ( String, Html msg )
rows config snapshot counted classCars field =
    let
        add (( _, item ) as pair) ( behind, acc ) =
            let
                back =
                    group counted.lead item

                lines =
                    row config snapshot classCars pair :: acc
            in
            if back == behind then
                ( behind, lines )

            else
                ( back, ( "splits-" ++ item.metadata.carNumber, division back ) :: lines )
    in
    List.foldl add ( Just 0, [] ) field
        |> Tuple.second
        |> List.reverse


{-| How far back a car sits: the laps between it and the class leader while it is
running, and nothing at all for a car that has stopped -- which is not lapped so
much as out, and is classified among the others rather than distanced by them.
-}
group : Int -> CarAt -> Maybe Int
group lead item =
    if Status.hasRetired item.status then
        Nothing

    else
        Just (lead - item.standing.lapsCompleted)


{-| The rule between two groups of a class, naming what separates them.
-}
division : Maybe Int -> Html msg
division back =
    let
        words =
            case back of
                Nothing ->
                    "Retired"

                Just laps ->
                    lapsText laps ++ " down"
    in
    div
        [ class "flex items-center gap-x-1.5 pt-1 text-[9px] leading-none uppercase tracking-[0.08em] whitespace-nowrap text-muted-foreground" ]
        [ div [ class "h-px flex-1 bg-border" ] []
        , div [ class "tabular-nums" ] [ text words ]
        , div [ class "h-px flex-1 bg-border" ] []
        ]


{-| How many laps, in the words the rest of the app uses for a gap of laps.
-}
lapsText : Int -> String
lapsText laps =
    Gap.toString (Gap.laps laps)
        |> String.dropLeft 2


{-| The row's tracks: the class place and the compact badge, each held two
lines; the two names, which are what give when there is no room; the interval;
and the photograph against the edge. The team and the lane's marks fill the
second line under the name and the reading.

Three class columns do not fit a 1440 viewport: this is the width budget the
tracks are drawn to, and why the row spends its edge on the photograph rather
than on another reading.

-}
rowClass : String
rowClass =
    "w-full grid grid-cols-[0.875rem_1.625rem_minmax(0,1fr)_3.375rem_5.25rem] items-start gap-x-[3px] gap-y-[2px] px-0.5 py-[2px] rounded text-left transition-colors cursor-pointer"


ordinal : CarAt -> Html msg
ordinal item =
    div
        [ class
            ("col-start-1 row-span-2 self-center text-[10px] tabular-nums whitespace-nowrap text-right "
                ++ (if item.standing.positionInClass == 1 then
                        ""

                    else
                        "text-muted-foreground"
                   )
            )
        ]
        [ text (String.fromInt item.standing.positionInClass) ]


{-| What the car is doing rather than where it stands: standing in its box,
driving out of the lane, stopped for good -- marked under the interval, where a
move arrow would have stood. A car on the road is marked nowhere, and its
track is drawn even then.
-}
now : CarAt -> Html msg
now item =
    case item.status of
        Status.InPit ->
            chip "PIT"

        Status.OutLap ->
            chip "OUT"

        Status.Retired ->
            div [ class "col-start-4 row-start-2 me-1.5 justify-self-end text-[10px] leading-[18px] whitespace-nowrap text-muted-foreground", attribute "data-lane" "" ]
                [ text "Retired" ]

        _ ->
            div [ class "col-start-4 row-start-2 me-1.5", attribute "data-lane" "" ] []


chip : String -> Html msg
chip word =
    div
        [ class "col-start-4 row-start-2 me-1.5 justify-self-end inline-flex items-center justify-center rounded-full border border-border bg-card px-1 text-[9px] font-bold leading-4 whitespace-nowrap text-muted-foreground"
        , attribute "data-lane" ""
        ]
        [ text word ]


{-| What the class-mate ahead is by, which is not what whoever is ahead is by: a
Hypercar standing between two LMP2 cars is on the road between them and is timed
with them, and `Snapshot.gapBetween` adds the intervals along that road rather
than counting the cars on it.

The head of a class is ahead of nobody in its class and draws no reading at all.

-}
gapAhead : Snapshot -> Maybe CarAt -> CarAt -> Html msg
gapAhead snapshot ahead chasing =
    -- The track is always drawn, empty where there is no reading: the row's
    -- other tracks name their columns rather than being auto-placed, and a
    -- track that sometimes is not there at all would shift its neighbours.
    div [ class "col-start-4 me-1.5 justify-self-end text-[10px] leading-[18px] tabular-nums whitespace-nowrap text-muted-foreground" ]
        [ case ahead of
            Nothing ->
                text ""

            Just inFront ->
                -- Nothing is measured between two cars that are not both on the road;
                -- the rule above the ones that stopped is what says as much.
                if Status.hasRetired chasing.status || Status.hasRetired inFront.status then
                    text ""

                else
                    text (Gap.toString (gapTo inFront chasing snapshot))
        ]


{-| The interval between two cars of a class: the road between them added up, or,
where it cannot be added up -- a car in the pit lane is timed at no line -- the
laps between them. Two cars on the same lap give neither reading, which is the
dash a timing tower leaves a car standing in the lane.
-}
gapTo : CarAt -> CarAt -> Snapshot -> Gap
gapTo inFront chasing snapshot =
    Snapshot.gapBetween inFront chasing snapshot
        |> Maybe.map Gap.seconds
        |> Maybe.withDefault (Gap.laps (inFront.standing.lapsCompleted - chasing.standing.lapsCompleted))
