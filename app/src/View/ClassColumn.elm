module View.ClassColumn exposing (view)

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

@docs view

-}

import Html exposing (Html, button, div, text)
import Html.Attributes exposing (attribute, class, style, title)
import Html.Events exposing (onClick)
import Html.Keyed as Keyed
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap.Performance as Performance
import Motorsport.Race.Car exposing (CarNumber)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Status as Status exposing (Status)
import Motorsport.Wec.Class as Class exposing (Class)
import UI.Shadcn.Card as Card
import View.CarDetail.Header as Header
import View.CarNumberBadge as CarNumberBadge
import View.ClassMark as ClassMark


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
    , onClose : Maybe msg
    , grip : Maybe (Html msg)
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
        -- measured to. The head of the class is ahead of nobody, and until the class
        -- has completed a lap nobody is measured against anybody: the column is the
        -- starting grid, and a reading down it would be one the timing has not taken.
        field =
            let
                ahead =
                    if lead > 0 then
                        List.map Just cars

                    else
                        List.repeat (List.length cars) Nothing
            in
            List.map2 Tuple.pair (Nothing :: ahead) cars

        -- What the class leader has completed, which is the lap every other car
        -- of the class is measured against.
        lead =
            case cars of
                first :: _ ->
                    first.standing.lapsCompleted

                _ ->
                    0
    in
    Card.card
        [ attribute "data-class-column" (Class.toString class_) ]
        [ div [ class "flex-1 min-h-0 grid grid-rows-[minmax(0,1fr)]" ]
            [ Card.content []
                [ div [ class "h-full min-h-0 grid grid-rows-[auto_minmax(0,1fr)] gap-y-1.5" ]
                    [ head config class_ cars
                    , Keyed.node "div"
                        [ class "min-h-0 overflow-y-auto grid auto-rows-min content-start gap-y-px" ]
                        (rows config snapshot lead field)
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


{-| One car of the class on one line: where it stands, who is driving, what the
class-mate ahead is by, and what the car is doing right now.

The readings sit in tracks of their own -- place, number, name, gap, now -- so
each is a column down the class rather than a string of words, and only the name
is allowed to give way. The interval is drawn before the lap being driven because
the strip's edge takes the rightmost reading, and the interval is what a class
column is for.

The ordinal is the class's, which is what this column is for: a car is 1st here
and 41st on the standings beside it, and both are true.

-}
row : Config msg -> Snapshot -> ( Maybe CarAt, CarAt ) -> ( String, Html msg )
row config snapshot ( ahead, item ) =
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
         , title (metadata.team ++ " · " ++ Driver.toInitialAndSurname item.currentDriver ++ lane item)
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
        , now item
        ]
    )


{-| The class down the column, a rule wherever the classification moves to another
group. The first division a class makes is not visible in a gap read in seconds:
the cars above the rule are fighting the race and the ones below are finishing
their own.

Keyed by the car a rule starts at, which no other row can claim.

-}
rows : Config msg -> Snapshot -> Int -> List ( Maybe CarAt, CarAt ) -> List ( String, Html msg )
rows config snapshot lead field =
    let
        add (( _, item ) as pair) ( behind, acc ) =
            let
                back =
                    group lead item

                lines =
                    row config snapshot pair :: acc
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


{-| What the car is doing right now: standing in its box, driving out of the lane,
stopped for good, or on the road driving a lap -- in the colour of how that lap
reads against the records as they stood at this moment, which is what says who is
pushing right now.

The lane and the running lap share a track because they answer one question, and
the lane wins where both could be said: a car in its box is not being scored
against the field, and its lap is held in the row's title. The stops a class has
made is the first thing a race splits on, and the mark is the lane's own grey, as
it is in the standings and on the tracker.

A retired car has no lap running, and the elapsed time the snapshot leaves on it
belongs to a lap it finished before it stopped.

-}
now : CarAt -> Html msg
now item =
    case item.status of
        Status.InPit ->
            chip "PIT"

        Status.OutLap ->
            chip "OUT"

        Status.Retired ->
            div [ class "justify-self-end text-[10px] whitespace-nowrap text-muted-foreground" ]
                [ text "Retired" ]

        _ ->
            div
                [ class "justify-self-end text-[10px] tabular-nums whitespace-nowrap"
                , style "color" (Performance.textColorOf item.currentLap.performance)
                ]
                [ text (Duration.toStringToTenths item.currentLap.elapsed) ]


{-| The lap a car is still driving while the lane has it, which the row's title
holds because the lane's mark takes the track.
-}
lane : CarAt -> String
lane item =
    case item.status of
        Status.InPit ->
            " · in the pit lane, driving " ++ Duration.toStringToTenths item.currentLap.elapsed

        Status.OutLap ->
            " · out of the pit lane, driving " ++ Duration.toStringToTenths item.currentLap.elapsed

        _ ->
            ""


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
