module View.ClassColumn exposing (view)

{-| One class of the field as a column of the strip: its cars in running order,
each measured against the class-mate ahead of it.

The standings to the left of the strip count the whole field; this counts one
class. Every reading is taken down the class rather than down the field, which is
what the field hides while a race is still sorting itself out: the interval is to
the class-mate ahead rather than to whoever is ahead, the reference lap is the
class's own fastest rather than the race's, a move is counted in the class rather
than among the 62 cars on the standings beside it, and the cars are all the cars
the class has, leader first.

A row picks the car it names, whose own column opens beside this one, so a class
can be followed from its order here and from a car's detail at the same time.

The foot of the column does not follow the running order: the cars ranked there
are ranked by the pace of the last laps and by how near their next stop they
are, and the laps that made both are drawn as dots -- readings the standings
cannot show, a car that lost a lap in the pits running the quickest race of
its class and standing fifteenth in it at the same time.

@docs view

-}

import Dict exposing (Dict)
import Html exposing (Html, button, div, text)
import Html.Attributes exposing (attribute, class, style, title)
import Html.Events exposing (onClick)
import Html.Keyed as Keyed
import Internal.Statistics as Statistics
import Motorsport.Analysis.ClassPositions as ClassPositions
import Motorsport.Analysis.Pace as Pace
import Motorsport.Analysis.Stint as Stint
import Motorsport.Chart.LapStrip as LapStrip
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap exposing (Lap)
import Motorsport.Leaderboard as Leaderboard
import Motorsport.Position exposing (Position)
import Motorsport.Race.Car exposing (CarNumber)
import Motorsport.Race.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Status as Status exposing (Status)
import Motorsport.Wec.Class as Class exposing (Class)
import UI.Shadcn.Card as Card
import View.CarDetail.Header as Header
import View.CarNumberBadge as CarNumberBadge
import View.ClassMark as ClassMark


{-| What the column is given: the two ways a row answers a press -- the car has
no column and so is picked, or has one already and so the strip goes to it --
which cars have columns, where the class's cars started on the grid, and the corner
controls every column carries.

`onSelect` and `onReveal` are held as they are handed over, so pass message
constructors: the rows are rebuilt on every frame of playback, and a lambda built
afresh per render rewrites every row of every class on every frame.

-}
type alias Config msg =
    { onSelect : CarNumber -> msg
    , onReveal : CarNumber -> msg
    , withColumns : List CarNumber
    , onClose : Maybe msg
    , grip : Maybe (Html msg)
    , startPosition : CarNumber -> Maybe Position
    }


{-| What the column counts off the class as a whole, once a frame: the laps the
class leader has completed, which is what every car's distance is measured
against, and where each car started among its own class-mates, which is what its
move is measured against.
-}
type alias Count =
    { lead : Int
    , grid : Dict CarNumber Position
    }


{-| The class ranked within itself. A car the grid has no place for is drawn as
having moved nowhere.
-}
count : (CarNumber -> Maybe Position) -> List CarAt -> Count
count startPosition cars =
    { lead =
        case cars of
            first :: _ ->
                first.standing.lapsCompleted

            _ ->
                0
    , grid =
        cars
            |> List.filterMap
                (\car ->
                    Maybe.map (\start -> ( car.metadata.carNumber, start )) (startPosition car.metadata.carNumber)
                )
            |> List.sortBy Tuple.second
            |> List.indexedMap (\index ( number, _ ) -> ( number, index + 1 ))
            |> Dict.fromList
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

        history =
            Snapshot.lapHistory snapshot

        -- Each car with the class-mate ahead of it, which is the car its gap is
        -- measured to. The head of the class is ahead of nobody, and until the class
        -- has completed a lap nobody is measured against anybody: the column is the
        -- starting grid, and a reading down it would be one the timing has not taken.
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
            count config.startPosition cars
    in
    Card.card
        [ attribute "data-class-column" (Class.toString class_) ]
        [ div [ class "flex-1 min-h-0 grid grid-rows-[minmax(0,1fr)]" ]
            [ Card.content []
                [ div [ class "h-full min-h-0 grid grid-rows-[auto_minmax(0,1fr)_auto] gap-y-1.5" ]
                    [ head config class_ cars
                    , Keyed.node "div"
                        [ class "min-h-0 overflow-y-auto grid auto-rows-min content-start gap-y-px" ]
                        (rows config snapshot counted field)
                    , footer history class_ snapshot counted cars
                    ]
                ]
            ]
        ]


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
            , div [ class "flex items-start gap-x-1" ] (corner config)
            ]
        , reference cars
        ]


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


{-| One car of the class on one line: where it stands in the class, who is driving,
what the class-mate ahead is by, and how many places of the class it has moved
since the grid.

The readings sit in tracks of their own -- place, number, name, interval, move --
so each is a column down the class rather than a string of words, and only the name
is allowed to give way. Three class columns do not fit a 1440 viewport, so the
tracks are ordered by what is worth losing at the strip's edge: the interval before
the move.

The ordinal is the class's, which is what this column is for: a car is 1st here
and 41st on the standings beside it, and both are true.

-}
row : Config msg -> Snapshot -> Count -> ( Maybe CarAt, CarAt ) -> ( String, Html msg )
row config snapshot counted ( ahead, item ) =
    let
        metadata =
            item.metadata

        picked =
            List.member metadata.carNumber config.withColumns
    in
    ( metadata.carNumber
    , button
        ([ attribute "aria-label" ("Car #" ++ metadata.carNumber ++ " in " ++ Class.toString metadata.class)
         , attribute "aria-pressed"
            (if picked then
                "true"

             else
                "false"
            )
         , class rowClass
         , title (metadata.team ++ " · " ++ Driver.toInitialAndSurname item.currentDriver)
         ]
            ++ (if picked then
                    -- The car's own colour, thinned enough to write on: the same
                    -- mark a row of the standings wears once its car is up.
                    [ style "background-color"
                        ("color-mix(in oklch, " ++ metadata.manufacturer.color ++ " 25%, transparent)")
                    , onClick (config.onReveal metadata.carNumber)
                    ]

                else
                    [ onClick (config.onSelect metadata.carNumber)
                    , class "hover:bg-accent/40"
                    ]
               )
        )
        [ ordinal item
        , CarNumberBadge.viewRow metadata
        , div [ class "min-w-0 truncate text-[11px] font-semibold leading-[18px]" ] [ text (Driver.toSurname item.currentDriver) ]
        , gapAhead snapshot ahead item
        , now counted item
        ]
    )


{-| The class down the column, a rule wherever the classification moves to another
group. The first division a class makes is not visible in a gap read in seconds:
the cars above the rule are fighting the race and the ones below are finishing
their own.

Keyed by the car a rule starts at, which no other row can claim.

-}
rows : Config msg -> Snapshot -> Count -> List ( Maybe CarAt, CarAt ) -> List ( String, Html msg )
rows config snapshot counted field =
    let
        add (( _, item ) as pair) ( behind, acc ) =
            let
                back =
                    group counted.lead item

                lines =
                    row config snapshot counted pair :: acc
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


{-| The rule between two groups of a class, naming what separates them: how many
laps back the cars below are, or that the cars below are the ones that stopped.
The class is drawn in classification order, so a group comes in one block and
there is one rule per group.
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


{-| The row's own tracks: the class place, the number, the name which is what
gives when there is no room, and two readings of their own width so the numbers
line up down the class.
-}
rowClass : String
rowClass =
    "w-full grid grid-cols-[0.875rem_auto_minmax(0,1fr)_3.5rem_2.25rem] items-center gap-x-[3px] px-0.5 py-[2px] rounded text-left transition-colors cursor-pointer"


ordinal : CarAt -> Html msg
ordinal item =
    div
        [ class
            ("text-[10px] tabular-nums whitespace-nowrap text-right "
                ++ (if item.standing.positionInClass == 1 then
                        ""

                    else
                        "text-muted-foreground"
                   )
            )
        ]
        [ text (String.fromInt item.standing.positionInClass) ]


{-| What the car is doing: standing in its box, driving out of the lane, stopped
for good -- and on the road, how many places of its own class it has gained or lost
since the grid, in the arrows the standings' own Move column uses.

The lane wins the track where both could be said, since a car in its box is not
being scored against the field. A car moved nowhere in its class draws nothing at
all, which is how every car of the class reads until the race has moved it: the
classification is not the grid, so a place gained before the class has completed a
lap would be a claim the timing has not made.

-}
now : Count -> CarAt -> Html msg
now counted item =
    case item.status of
        Status.InPit ->
            chip "PIT"

        Status.OutLap ->
            chip "OUT"

        Status.Retired ->
            div [ class "justify-self-end text-[10px] whitespace-nowrap text-muted-foreground" ]
                [ text "Retired" ]

        _ ->
            div [ class "justify-self-end leading-[18px]" ]
                [ if counted.lead > 0 then
                    Leaderboard.viewPositionChangeInline
                        { startPosition = Dict.get item.metadata.carNumber counted.grid
                        , position = item.standing.positionInClass
                        }

                  else
                    text ""
                ]


chip : String -> Html msg
chip word =
    div
        [ class "justify-self-end inline-flex items-center justify-center rounded-full border border-border bg-card px-1 text-[9px] font-bold leading-4 whitespace-nowrap text-muted-foreground" ]
        [ text word ]


{-| What the class-mate ahead is by, which is not what whoever is ahead is by: a
Hypercar standing between two LMP2 cars is on the road between them and is timed
with them, and `Snapshot.gapBetween` adds the intervals along that road rather
than counting the cars on it.

The head of a class is ahead of nobody in its class and draws no reading at all,
which is what a classification leaves the head of a class.

-}
gapAhead : Snapshot -> Maybe CarAt -> CarAt -> Html msg
gapAhead snapshot ahead chasing =
    case ahead of
        Nothing ->
            text ""

        Just inFront ->
            -- Nothing is measured between two cars that are not both on the road;
            -- the rule above the ones that stopped is what says as much.
            if Status.hasRetired chasing.status || Status.hasRetired inFront.status then
                text ""

            else
                div [ class "justify-self-end text-[10px] tabular-nums whitespace-nowrap text-muted-foreground" ]
                    [ text (Gap.toString (gapTo inFront chasing snapshot)) ]


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



-- PACE


{-| The whole foot: what the class is quickest at now, which of them will have
to do something about it first, and what those few have been doing about it
lap by lap.
-}
footer : LapHistory -> Class -> Snapshot -> Count -> List CarAt -> Html msg
footer history class_ snapshot counted cars =
    let
        dues =
            dueBoard history cars
    in
    div [ class "grid gap-y-1.5" ]
        [ pace history counted cars
        , stops history class_ snapshot counted dues
        , lapStrip history counted dues
        ]


{-| How many of the class leader's completed laps pace is read over. Short
enough that a stop is still the story three laps later, long enough that one
push lap is not.
-}
windowLaps : Int
windowLaps =
    5


{-| How many cars the board keeps. Who is quickest just now is a reading of the
quickest few, not of the class.
-}
boardPlaces : Int
boardPlaces =
    5


{-| A car and the pace that put it on the board.
-}
type alias Pace =
    { car : CarAt
    , lap : Duration
    }


{-| The foot of the column: the class ranked by the pace of the last laps
instead of by where the timing stands it. The standings above answer who is
ahead; this answers who is quickest, and the two come apart every time a car
loses time in the lane rather than to the class-mates -- the board is where a
car running the quickest race of its class from fifteenth is visible.

The board is a display, not a second way to pick a car: every car on it is
already a row of the standings above.

-}
pace : LapHistory -> Count -> List CarAt -> Html msg
pace history counted cars =
    div [ class "border-t border-border pt-1 grid gap-y-px" ]
        (note "Pace" ("median of the last " ++ String.fromInt windowLaps ++ " laps")
            :: (case board history counted cars of
                    [] ->
                        [ div [ class "text-[10px] text-muted-foreground" ] [ text "no racing laps" ] ]

                    quickest :: rest ->
                        List.indexedMap (entry quickest.lap) (quickest :: rest)
               )
        )


{-| A board's own heading: the word it is called and the small print saying
what its numbers are measured against.
-}
note : String -> String -> Html msg
note word reading =
    div [ class "flex items-baseline justify-between" ]
        [ label word
        , div [ class "text-[9px] text-muted-foreground" ] [ text reading ]
        ]


{-| Each car's median racing lap over the window, quickest first. A retired
car and a car that ran no racing lap in the window are off the board; the rest
keep company whoever they are, since pace is not standing.

The median is the pace: a lone push lap is a qualifying effort and a lap stuck
behind a slower car is traffic, and neither is how fast the car is going round
right now. The laps themselves are the car's own outlier fence cut -- see
[`Pace.racingTimes`](Motorsport-Analysis-Pace).

-}
board : LapHistory -> Count -> List CarAt -> List Pace
board history counted cars =
    if counted.lead < 1 then
        []

    else
        let
            range =
                { first = max 1 (counted.lead - windowLaps + 1), last = counted.lead }
        in
        cars
            |> List.filter (\car -> not (Status.hasRetired car.status))
            |> List.filterMap
                (\car ->
                    Statistics.median (Pace.racingTimes range (LapHistory.get car.metadata.carNumber history))
                        |> Maybe.map (\lap -> { car = car, lap = lap })
                )
            |> List.sortBy .lap
            |> List.take boardPlaces


{-| One car of the board. The quickest of them carries its own pace, because a
pace without a number is a claim; the rest are gaps to it, which is what a pit
wall reads and what gives way at the strip's edge.
-}
entry : Duration -> Int -> Pace -> Html msg
entry best index item =
    div
        [ class "grid grid-cols-[0.875rem_auto_minmax(0,1fr)_auto] items-center gap-x-[3px] px-0.5"
        , title
            (Driver.toInitialAndSurname item.car.currentDriver
                ++ " · "
                ++ Duration.toString item.lap
            )
        ]
        [ div [ class "text-[10px] tabular-nums whitespace-nowrap text-right text-muted-foreground" ]
            [ text (String.fromInt (index + 1)) ]
        , CarNumberBadge.viewRow item.car.metadata
        , div [ class "min-w-0 truncate text-[11px] leading-[18px] text-muted-foreground" ]
            [ text (Driver.toSurname item.car.currentDriver) ]
        , div
            [ class
                ("justify-self-end text-[10px] tabular-nums whitespace-nowrap "
                    ++ (if index == 0 then
                            ""

                        else
                            "text-muted-foreground"
                       )
                )
            ]
            [ text
                (if index == 0 then
                    Duration.toString item.lap

                 else
                    "+" ++ Duration.toString (item.lap - best)
                )
            ]
        ]



-- STOPS


{-| How many laps ahead of its own median a stop still counts as coming up.
About a quarter of a stint: inside it the call is being made now, not on the
next saving of fuel.
-}
soonestLaps : Int
soonestLaps =
    3


{-| How many laps back the stops board measures a move over -- the same stretch
a car card is a thumbnail of.
-}
placeWindow : Int
placeWindow =
    20


{-| A car and how near its next stop it is: `laps` counts the ones between the
run it is on and the length the runs behind it took, so it is negative once
the run has gone on past the car's own habit.
-}
type alias Due =
    { car : CarAt
    , laps : Int
    , stint : Int
    , median : Int
    }


{-| The foot's second board: the class ranked by how soon each car will be
called, nearest stop first.

The standings answer who is ahead and the pace board who is quickest; neither
answers when, which is what a race between pit windows is decided by. The
window is each car's own habit -- the median of its finished runs -- so a class
running two strategies at once still reads: the board says which of them will
have to blink first, not which is furthest from some class-wide number.

-}
stops : LapHistory -> Class -> Snapshot -> Count -> List Due -> Html msg
stops history class_ snapshot counted dues =
    div [ class "border-t border-border pt-1 grid gap-y-px" ]
        (note "Stops" "laps to its own median stint"
            :: (if List.isEmpty dues then
                    [ div [ class "text-[10px] text-muted-foreground" ] [ text "no finished stint yet" ] ]

                else
                    List.indexedMap (stopRow (placeMoves counted class_ snapshot)) dues
               )
        )


{-| Each running car's own median read against the run it is on. A car in the
lane, or on a first run with no finished one behind it, has no habit to be due
against and is off the board until it has one; a retired car has no next stop.

The nearest few are kept, and when nobody is near the single nearest is: a
board of a class nobody will call for four laps says nothing, but which car
they will call first still says something.

-}
dueBoard : LapHistory -> List CarAt -> List Due
dueBoard history cars =
    let
        dues =
            cars
                |> List.filter (\car -> not (Status.hasRetired car.status))
                |> List.filterMap (\car -> dueOf car history)
                |> List.sortBy .laps

        soon =
            List.filter (\due -> due.laps <= soonestLaps) dues
    in
    List.take boardPlaces
        (if List.isEmpty soon then
            List.take 1 dues

         else
            soon
        )


dueOf : CarAt -> LapHistory -> Maybe Due
dueOf car history =
    let
        summary =
            Stint.summarize (LapHistory.get car.metadata.carNumber history)
    in
    Maybe.map2 (\current median -> { car = car, laps = median - current.lapCount, stint = current.lapCount, median = median })
        summary.current
        summary.medianStintLength


{-| The class's places of twenty laps ago, per car -- what each row's arrow is
measured from: the place the oldest classified lap in the window carries, for
the car and not for the class. A car the window holds no classified lap for
gives nothing and draws no arrow.
-}
placeMoves : Count -> Class -> Snapshot -> Dict CarNumber Position
placeMoves counted class_ snapshot =
    if counted.lead < 1 then
        Dict.empty

    else
        ClassPositions.byCar { first = max 1 (counted.lead - placeWindow + 1), last = counted.lead } class_ snapshot
            |> List.filterMap
                (\( car, points ) ->
                    List.head points |> Maybe.map (\first -> ( car.metadata.carNumber, first.position ))
                )
            |> Dict.fromList


{-| One car of the board: how far its place in the race has moved over the last
laps -- the standings' own arrow, measured against twenty laps ago rather than
the grid, and among the whole field rather than in its class, because it is
the race place the window holds -- and how many laps the call has left. The
nearest stop carries its own number, the rest their laps to it.

The move is the whole of what a line through these places could say, and the
arrow is its honest telling: over twenty laps a class swaps places every lap
as its cars pit, and a line drawn through that swings the height of a row on
other cars' stops, saying _fighting_ for a car that netted nothing.

-}
stopRow : Dict CarNumber Position -> Int -> Due -> Html msg
stopRow moves index item =
    div
        [ class "grid grid-cols-[0.875rem_auto_minmax(0,1fr)_2.25rem_2.75rem] items-center gap-x-[3px] px-0.5"
        , title (Driver.toInitialAndSurname item.car.currentDriver ++ " · lap " ++ String.fromInt item.stint ++ " of a median " ++ String.fromInt item.median)
        ]
        [ div [ class "text-[10px] tabular-nums whitespace-nowrap text-right text-muted-foreground" ]
            [ text (String.fromInt (index + 1)) ]
        , CarNumberBadge.viewRow item.car.metadata
        , div [ class "min-w-0 truncate text-[11px] leading-[18px] text-muted-foreground" ]
            [ text (Driver.toSurname item.car.currentDriver) ]
        , div [ class "justify-self-end leading-[18px]" ]
            [ Leaderboard.viewPositionChangeInline { startPosition = Dict.get item.car.metadata.carNumber moves, position = item.car.standing.position } ]
        , div
            [ class
                ("justify-self-end text-[10px] tabular-nums whitespace-nowrap "
                    ++ (if index == 0 then
                            ""

                        else
                            "text-muted-foreground"
                       )
                )
            ]
            [ text (dueText item.laps) ]
        ]


{-| The call in the words a pit wall says it: the laps it has left, the call
due this lap, and how far the run has run on once its habit is behind it.
-}
dueText : Int -> String
dueText laps =
    if laps < 0 then
        "over " ++ String.fromInt (negate laps)

    else if laps == 0 then
        "now"

    else
        "in " ++ String.fromInt laps



-- LAPS


{-| How many laps a strip reaches back over. Long enough for the shape of a run
to be visible -- a few tenths shaved off in a row, a second lost every lap --
and short enough that the dots stay dots.
-}
stripLaps : Int
stripLaps =
    20


{-| Wide enough that twenty dots stay separate at the room the move arrow's
track leaves in the row.
-}
stripWidth : Float
stripWidth =
    96


{-| The same few cars the stops board names, their racing laps as dots. The
board says when each will be called; this says what they have been doing about
it -- dots held high on the scale are a car on a push, dots walking down it a
car saving, and the gap where a car's pit lap was is the stop that moved its
call forward.

The scale is the shown cars' together, never each car's own: a strip scaled to
its own quickest and slowest lap draws a car saving fuel with the same steep
shape as a car on a push, which is the opposite news. What the few shown span
is what the dots are read against, and a car joining them with a lap none of
them ran sits on the top or bottom of the strip on purpose.

-}
lapStrip : LapHistory -> Count -> List Due -> Html msg
lapStrip history counted dues =
    let
        range =
            { first = max 1 (counted.lead - stripLaps + 1), last = counted.lead }

        strips =
            dues
                |> List.map
                    (\due ->
                        ( due, Pace.racingLaps range (LapHistory.get due.car.metadata.carNumber history) )
                    )

        scale =
            case
                strips
                    |> List.concatMap (Tuple.second >> List.filterMap .time)
                    |> (\times -> ( List.minimum times, List.maximum times ))
            of
                ( Just quickest, Just slowest ) ->
                    Just { laps = range, quickest = quickest, slowest = slowest }

                _ ->
                    Nothing
    in
    div [ class "border-t border-border pt-1 grid gap-y-px" ]
        (note "Laps" ("last " ++ String.fromInt stripLaps ++ " racing laps, one scale")
            :: (case scale of
                    Nothing ->
                        [ div [ class "text-[10px] text-muted-foreground" ] [ text "no racing laps" ] ]

                    Just shared ->
                        List.indexedMap (stripRow shared) strips
               )
        )


{-| One car of the board, its dots, and nothing else -- the median lap and the
pace behind the quickest are the board above's readings.
-}
stripRow : LapStrip.Scale -> Int -> ( Due, List Lap ) -> Html msg
stripRow scale index ( due, laps ) =
    div
        [ class "grid grid-cols-[0.875rem_auto_minmax(0,1fr)_auto] items-center gap-x-[3px] px-0.5"
        , title (Driver.toInitialAndSurname due.car.currentDriver ++ " · " ++ spanText laps)
        ]
        [ div [ class "text-[10px] tabular-nums whitespace-nowrap text-right text-muted-foreground" ]
            [ text (String.fromInt (index + 1)) ]
        , CarNumberBadge.viewRow due.car.metadata
        , div [ class "min-w-0 truncate text-[11px] leading-[18px] text-muted-foreground" ]
            [ text (Driver.toSurname due.car.currentDriver) ]
        , div [ class "justify-self-end" ]
            [ LapStrip.strip { width = stripWidth, height = 16 } scale due.car.metadata.manufacturer.color laps ]
        ]


{-| The car's own quickest and slowest of the strip, which is what its dots are
in fact worth -- the strip itself is drawn against the few shown together.
-}
spanText : List Lap -> String
spanText laps =
    case ( List.filterMap .time laps |> List.minimum, List.filterMap .time laps |> List.maximum ) of
        ( Just quickest, Just slowest ) ->
            Duration.toString quickest ++ " – " ++ Duration.toString slowest

        _ ->
            "no racing laps"
