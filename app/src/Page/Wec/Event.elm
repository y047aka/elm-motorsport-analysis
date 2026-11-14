module Page.Wec.Event exposing (Model, Msg, init, subscriptions, update, view)

{-| WEC event page (`/wec/:season/:event`). Route parameters are passed into
`init` by `Main`.

@docs Model, Msg, init, subscriptions, update, view

-}

import Browser.Dom
import Browser.Events
import Dict exposing (Dict)
import Drag
import Drag.Handle as Handle
import Effect exposing (Effect)
import Html exposing (Html, a, button, div, main_, nav, span, text)
import Html.Attributes as Attributes exposing (attribute)
import Html.Events exposing (onClick)
import Html.Keyed
import Html.Lazy
import Json.Decode as Decode
import List.Extra
import Motorsport.Analysis.Energy as Energy
import Motorsport.Analysis.Strategy exposing (PitCycle)
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock as Clock
import Motorsport.Position exposing (Position)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Replay as Replay
import Motorsport.Wec.Class as Class exposing (Class)
import Page.Wec.Columns as Columns
import Page.Wec.Resize as Resize
import Route
import Shared
import Shared.Msg
import Task
import Time
import UI.Notice as Notice
import UI.Shadcn.Card as Card
import View exposing (View)
import View.CarDetail as CarDetail
import View.CarDetail.Header as Header
import View.CarNumberBadge as CarNumberBadge
import View.ClassColumn as ClassColumn
import View.EventsColumn as EventsColumn
import View.Feed as Feed
import View.LiveStandings as LiveStandings
import View.PlaybackControls as PlaybackControls



-- MODEL


type alias Model =
    { strip : Columns.Model
    , rowTrace : Dict String ClassColumn.Trace
    , eventsColumn : EventsColumn.Model
    , comparison : CarDetail.Comparison
    , standings : Resize.Model
    }


standingsFence : Resize.Fence
standingsFence =
    { min = LiveStandings.minWidth
    , max = LiveStandings.maxWidth
    , step = 20
    }


init : { season : String, event : String } -> ( Model, Effect Msg )
init params =
    ( { strip = Columns.init
      , rowTrace = Dict.empty
      , eventsColumn = EventsColumn.init
      , comparison = CarDetail.initialComparison
      , standings = Resize.init LiveStandings.width
      }
    , Effect.sendSharedMsg (Shared.Msg.FetchJson_Wec { season = params.season, event = params.event })
    )



-- UPDATE


type Msg
    = StartRace
    | PauseRace
    | FocusColumn Columns.StripKey
    | ColumnsMsg Columns.Msg
    | ResizeMsg Resize.Msg
    | RowTraceChosen Class ClassColumn.Trace
    | EventsColumnMsg Feed.Msg
    | ReplayMsg Replay.Msg
    | CarDetailMsg CarDetail.Msg


update : Shared.Model -> Msg -> Model -> ( Model, Effect Msg )
update shared msg m =
    case msg of
        StartRace ->
            ( m, Task.perform (Replay.Start >> ReplayMsg) Time.now |> Effect.sendCmd )

        PauseRace ->
            ( m, Task.perform (Replay.Pause >> ReplayMsg) Time.now |> Effect.sendCmd )

        ColumnsMsg sub ->
            let
                ( strip, cmd ) =
                    Columns.update (field shared) sub m.strip
            in
            ( { m | strip = strip }, Effect.sendCmd (Cmd.map ColumnsMsg cmd) )

        ResizeMsg sub ->
            ( { m | standings = Resize.update standingsFence sub m.standings }, Effect.none )

        FocusColumn key ->
            let
                keys =
                    columnKeys shared m
            in
            case List.Extra.elemIndex key keys of
                Just index ->
                    -- Where the column stands, as it stands -- plus the gap's
                    -- slack, so the column before it stays a sliver in sight.
                    ( m
                    , Browser.Dom.setViewportOf Columns.stripId (Columns.gap + Columns.xOf (always Columns.width) keys index) 0
                        |> Task.onError (\_ -> Task.succeed ())
                        |> Task.perform (\_ -> ColumnsMsg Columns.Settled)
                        |> Effect.sendCmd
                    )

                Nothing ->
                    ( m, Effect.none )

        RowTraceChosen class_ trace ->
            ( { m | rowTrace = Dict.insert (Class.toString class_) trace m.rowTrace }, Effect.none )

        EventsColumnMsg feedMsg ->
            ( { m | eventsColumn = Feed.update feedMsg m.eventsColumn }, Effect.none )

        ReplayMsg replayMsg ->
            ( m, Effect.sendSharedMsg (Shared.Msg.ReplayMsg replayMsg) )

        CarDetailMsg detailMsg ->
            ( { m | comparison = CarDetail.update detailMsg m.comparison }, Effect.none )


{-| The field is read at the moment of the message, never kept: the strip's
update takes it as an argument and the class columns are read off it.
-}
field : Shared.Model -> Maybe Snapshot
field shared =
    Shared.loadedRound shared |> Maybe.map .snapshot



-- SUBSCRIPTIONS


subscriptions : Shared.Model -> Model -> Sub Msg
subscriptions shared _ =
    if Shared.isPlaying shared then
        Browser.Events.onAnimationFrame (Replay.Tick >> ReplayMsg)

    else
        Sub.none



-- VIEW


view : Shared.Model -> Model -> View Msg
view shared m =
    let
        maybeRound =
            Shared.loadedRound shared

        keys =
            columnKeys shared m
    in
    { title = "Wec"
    , body =
        [ main_
            [ Attributes.class "dark h-full grid grid-rows-[auto_1fr]"
            ]
            [ navigation keys (headerTitle shared) maybeRound
            , case maybeRound of
                Nothing ->
                    -- Named but not loaded. Nothing is drawn rather than the
                    -- round before it.
                    div [ Attributes.class "row-start-2" ] [ unavailable shared ]

                Just round ->
                    mainGrid round keys m
            ]
        ]
    }


{-| Nothing while a round is on its way, and why once it is not coming.
-}
unavailable : Shared.Model -> Html Msg
unavailable shared =
    case Shared.problem shared of
        Nothing ->
            text ""

        Just Shared.NotListed ->
            Notice.view
                { headline = "No such round."
                , detail = "The calendar does not list this season and event."
                }

        Just Shared.NoClassGrid ->
            Notice.view
                { headline = "This season cannot be read yet."
                , detail = "There is no class grid for it, so its cars have no classes to be put in."
                }

        Just (Shared.LoadFailed error) ->
            Notice.view
                { headline = "The round could not be loaded."
                , detail = Notice.httpError error
                }


{-| The strip's columns, in order, at the moment of the render or the
message. Read once per render and handed to everything that draws or names
a column: each reading costs the field walk the columns are resolved
against.
-}
columnKeys : Shared.Model -> Model -> List Columns.StripKey
columnKeys shared m =
    Shared.loadedRound shared
        |> Maybe.map
            (\round ->
                Columns.resolve round.snapshot (Columns.keysOf round.snapshot m.strip.order)
            )
        |> Maybe.withDefault []


headerTitle : Shared.Model -> String
headerTitle shared =
    Shared.roundId shared
        |> Maybe.map (\round -> round.name ++ " (" ++ String.fromInt round.season ++ ")")
        |> Maybe.withDefault ""


{-| The tracker's column, carried among the cars as any other is. Its ✕ is
the one thing that takes it away.

It carries `data-tracker-column`, which the visual tests locate it by.

-}
trackerCard : Bool -> Bool -> TrackerChart.Track -> Snapshot -> Html Msg
trackerCard several held track snapshot =
    Card.card [ attribute "data-tracker-column" "" ]
        [ div
            [ Attributes.class "flex-1 min-h-0 grid grid-rows-[minmax(0,1fr)]"
            ]
            [ Card.content []
                [ div [ Attributes.class "relative h-full w-full grid place-items-center" ]
                    [ TrackerChart.view TrackerChart.Full track snapshot
                    , div [ Attributes.class "absolute top-0 right-0 flex items-start gap-x-1" ]
                        (standingsTrigger :: cornerControls (corner several held Columns.Tracker))
                    ]
                ]
            ]
        ]


mainGrid : Shared.LoadedRound -> List Columns.StripKey -> Model -> Html Msg
mainGrid round keys m =
    let
        snapshot =
            round.snapshot

        replay =
            round.replay
    in
    div
        -- The whole class string is written intact: Tailwind generates a
        -- class only from a string it finds intact in the source, so one
        -- assembled from fragments silently ships no
        -- `grid-template-columns` at all, and every track sizes to its
        -- content.
        [ Attributes.class
            "row-start-2 h-full min-h-0 grid grid-cols-[auto_1fr] gap-2.5 p-[0_10px_10px_10px]"
        ]
        [ standingsCell keys m round.energy snapshot replay.race.cars
        , columnStrip "col-start-2" round.track round.timeline keys m round.pitCycles replay snapshot
        , standingsPopover
        , div [ attribute "aria-live" "polite", Attributes.class "sr-only" ] [ text m.strip.announcement ]
        ]


{-| Where each car started, by number: the grid the standings and a class's own
column measure a move against.

Foldr, so that where the source data has two cars under one number the one
running ahead wins, as in `Snapshot.get`.

-}
gridOf : List Car -> Dict CarNumber Position
gridOf cars =
    List.foldr (\car -> Dict.insert car.metadata.carNumber car.startPosition) Dict.empty cars


{-| The live standings, standing to the left of the strip rather than as one
of its columns, and a grip to drag them wider or narrower.
The grip stands in the gap between the two tracks: its container's `w-2.5`
and `-right-2.5` are `mainGrid`'s `gap-2.5`, so a change to one without the
other leaves the grip off the gap.
The column track is `auto`, so the strip gains and loses the width as the
drag goes on.
-}
standingsCell : List Columns.StripKey -> Model -> Energy.Table -> Snapshot -> List Car -> Html Msg
standingsCell keys m energy snapshot cars =
    let
        startPositions =
            gridOf cars
    in
    div
        [ Attributes.class "col-start-1 min-h-0 grid relative" ]
        [ LiveStandings.view
            { onSelect = pickCar
            , withColumns = List.map (.metadata >> .carNumber) (Columns.carsIn snapshot keys)
            , openColumn = openColumn keys
            , width = m.standings.width
            , startPosition = \number -> Dict.get number startPositions
            , energy = energy
            }
            snapshot
        , div [ Attributes.class "absolute -right-2.5 top-0 h-full z-10 grid w-2.5 place-items-center" ]
            [ Html.map ResizeMsg (Resize.grip m.standings) ]
        ]


{-| A car picked -- from the standings, or from the class's column it is running
in. Kept whole and top-level, because both panels' rows compare what they are
handed by reference; see `ClassColumn.Config`.

The strip scrolls to the column it opened, which is `Columns`'s to do.

-}
pickCar : CarNumber -> Msg
pickCar carNumber =
    ColumnsMsg (Columns.Open (Columns.Car carNumber))


{-| A car picked that has a column already: the strip goes to that column rather
than opening a second one.
-}
revealCar : CarNumber -> Msg
revealCar carNumber =
    FocusColumn (Columns.Car carNumber)


{-| The standings' message for a class: nothing where the class's column is
standing, and the column called for where the reader has closed it -- a class's
name in the standings is where a closed column is asked for again.
-}
openColumn : List Columns.StripKey -> Class -> Maybe Msg
openColumn keys class_ =
    let
        key =
            Columns.ClassColumn class_
    in
    if List.member key keys then
        Nothing

    else
        Just (ColumnsMsg (Columns.Open key))


{-| One keyed child of the strip: a grid of the width the column stands at,
whatever is drawn in it, standing as its placement says -- flush for a
resting one, an offset and a shadow for a carried one.
-}
stripColumn : String -> Float -> Columns.Placement -> Html Msg -> ( String, Html Msg )
stripColumn key width placement content =
    ( key
    , div
        (Attributes.class "shrink-0 grid"
            :: Attributes.style "width" (Columns.px width)
            :: Columns.placementAttributes placement
        )
        [ content ]
    )


columnStrip : String -> TrackerChart.Track -> Timeline -> List Columns.StripKey -> Model -> Dict String PitCycle -> Replay.Model -> Snapshot -> Html Msg
columnStrip cell track timeline keys m pitCycles replay snapshot =
    let
        several =
            List.length keys > 1

        placements =
            Columns.placements (always Columns.width) (Columns.carrying m.strip) keys

        standing =
            List.map (\car -> car.metadata.carNumber) (Columns.carsIn snapshot keys)

        columnCell key placement =
            stripColumn (Columns.keyName key)
                Columns.width
                placement
                (case key of
                    Columns.Car carNumber ->
                        Snapshot.get carNumber snapshot
                            |> Maybe.map
                                (\car ->
                                    Html.Lazy.lazy6 (carCard several) timeline (Columns.isCarried placement) m.comparison replay.race.cars snapshot car
                                )
                            |> Maybe.withDefault (text "")

                    Columns.ClassColumn class_ ->
                        classColumn several
                            standing
                            (Columns.isCarried placement)
                            (rowTrace m class_)
                            snapshot
                            (Maybe.withDefault pitCycleNone (Dict.get (Class.toString class_) pitCycles))
                            class_

                    Columns.Tracker ->
                        trackerCard several (Columns.isCarried placement) track snapshot

                    Columns.Events ->
                        EventsColumn.view
                            { corner = cornerControls (corner several (Columns.isCarried placement) Columns.Events)
                            , earlier = EventsColumnMsg Feed.ShowEarlierEvents
                            }
                            m.eventsColumn
                            replay.race.cars
                            timeline
                            replay.race.bestTimeChanges
                            (Clock.getElapsed replay.playback)
                )
    in
    case keys of
        [] ->
            -- Before any car has turned a lap.
            div [ Attributes.class (cell ++ " flex") ] [ Card.card [] [] ]

        _ ->
            -- Keyed on the column: a column matched by position instead would
            -- hand how far the reader had scrolled it to whichever column moved
            -- up into its place when the one before it was closed.
            Html.Keyed.node "div"
                ([ Attributes.id Columns.stripId
                 , Attributes.class (cell ++ " flex overflow-x-auto")
                 , Attributes.style "column-gap" (Columns.px Columns.gap)
                 ]
                    ++ (if Drag.isCarrying m.strip.carried then
                            [ Html.Events.on "scroll" (Decode.map (Columns.StripScrolled >> ColumnsMsg) (Decode.at [ "target", "scrollLeft" ] Decode.float)) ]

                        else
                            []
                       )
                )
                (List.map2 columnCell keys placements)


columnGrip : Bool -> Columns.StripKey -> Html Msg
columnGrip held key =
    Handle.view
        { id = Columns.gripId key
        , label = "Move this column"
        , held = held
        , onGrab = Columns.Grab key >> ColumnsMsg
        , onMove = Columns.Carrying >> ColumnsMsg
        , onDrop = Columns.Release >> ColumnsMsg
        , onCancel = Columns.Cancel >> ColumnsMsg
        , onStep = Columns.Step key >> ColumnsMsg
        }


type alias Corner =
    { onClose : Maybe Msg
    , grip : Maybe (Html Msg)
    }


{-| The corner every column carries: taking a column away is `Columns.Close`
for its key, and standing alone it has neither control.
-}
corner : Bool -> Bool -> Columns.StripKey -> Corner
corner several held key =
    if several then
        { onClose = Just (ColumnsMsg (Columns.Close key))
        , grip = Just (columnGrip held key)
        }

    else
        { onClose = Nothing
        , grip = Nothing
        }


{-| The corner drawn as a row, in the order every column that floats its
controls draws them in.
-}
cornerControls : Corner -> List (Html Msg)
cornerControls controls =
    List.filterMap identity [ controls.grip, Maybe.map Header.closeButton controls.onClose ]


{-| One class of the field, which is what the strip opens with: `View.ClassColumn`
draws its cars each against the class-mate ahead of it.
-}
classColumn : Bool -> List CarNumber -> Bool -> ClassColumn.Trace -> Snapshot -> PitCycle -> Class -> Html Msg
classColumn several standing held trace snapshot pitCycle class_ =
    let
        controls =
            corner several held (Columns.ClassColumn class_)
    in
    ClassColumn.view
        { onSelect = pickCar
        , onReveal = revealCar
        , withColumns = standing
        , trace = trace
        , onTrace = RowTraceChosen class_
        , onClose = controls.onClose
        , grip = controls.grip
        }
        snapshot
        pitCycle
        class_


{-| The answer for a class the race holds none of -- no scale, no window, and
the strategy trace draws nothing on it.
-}
pitCycleNone : PitCycle
pitCycleNone =
    { distance = 0, cycle = Nothing }


{-| `Class` carries a record, so each column's curve choice is kept under the
name its class prints.
-}
rowTrace : Model -> Class -> ClassColumn.Trace
rowTrace m class_ =
    Dict.get (Class.toString class_) m.rowTrace
        |> Maybe.withDefault ClassColumn.PaceTrace


carCard : Bool -> Timeline -> Bool -> CarDetail.Comparison -> List Car -> Snapshot -> CarAt -> Html Msg
carCard several timeline held comparison cars snapshot car =
    let
        carNumber =
            car.metadata.carNumber

        controls =
            corner several held (Columns.Car carNumber)
    in
    Card.card []
        -- A card's content does not shrink below what it holds, so the card
        -- settles the height here and the panel scrolls within it, under the
        -- header. The row is `minmax(0,1fr)` rather than `auto`: an `auto` row
        -- takes the content's height and overflows the card rather than
        -- cropping it.
        [ div
            [ Attributes.class "flex-1 min-h-0 grid grid-rows-[minmax(0,1fr)]" ]
            [ Card.content []
                [ CarDetail.view
                    { toMsg = CarDetailMsg
                    , onClose = controls.onClose
                    , grip = controls.grip
                    , comparison = comparison
                    , scrollId = Columns.scrollId carNumber
                    , onScroll = Columns.PanelScrolled carNumber >> ColumnsMsg
                    , timeline = timeline
                    }
                    cars
                    snapshot
                    car
                ]
            ]
        ]


{-| The press that opens the standings popover.

`popovertarget` resolves by id across the document, so the press need not stand near the popover it opens.

-}
standingsTrigger : Html Msg
standingsTrigger =
    button
        [ attribute "popovertarget" standingsPopoverId
        , attribute "popovertargetaction" "show"
        , Attributes.attribute "aria-label" "Open the standings"
        , Attributes.class "inline-flex items-center justify-center size-8 rounded-full text-sm cursor-pointer transition-colors hover:bg-accent hover:text-accent-foreground"
        ]
        [ text "⤢" ]


standingsPopoverId : String
standingsPopoverId =
    "standings-popover"


standingsPopover : Html Msg
standingsPopover =
    Html.node "div"
        [ Attributes.id standingsPopoverId
        , attribute "popover" "auto"

        -- Tailwind preflight cancels the UA's margin:auto, so set it explicitly to center.
        -- The popover has no containing block to size against but the viewport,
        -- so its width is set explicitly rather than left to shrink to content.
        , Attributes.class "m-auto w-11/12 max-w-[min(90vw,1200px)] p-4 rounded-xl overflow-y-auto max-h-screen"
        , Attributes.class "bg-popover text-popover-foreground backdrop-blur-lg border border-border shadow-glass"

        -- A closed popover is display:none by the UA, but its entrance
        -- transition still needs an explicit closed state to animate from.
        , Attributes.class "opacity-0 scale-95 transition-[opacity,scale] duration-200 [&:popover-open]:opacity-100 [&:popover-open]:scale-100"
        , Attributes.class "backdrop:bg-black/10"
        ]
        [ button
            [ attribute "popovertarget" standingsPopoverId
            , attribute "popovertargetaction" "hide"
            , Attributes.class "inline-flex items-center justify-center size-8 rounded-full text-sm cursor-pointer transition-colors hover:bg-accent hover:text-accent-foreground absolute right-2 top-2"
            ]
            [ text "✕" ]
        ]


navigation : List Columns.StripKey -> String -> Maybe Shared.LoadedRound -> Html Msg
navigation keys title maybeRound =
    nav
        [ Attributes.class "p-3 grid grid-cols-[auto_1fr_auto] items-center gap-x-10" ]
        [ div [ Attributes.class "flex items-center gap-2 whitespace-nowrap min-w-0" ]
            [ backLink
            , div [ Attributes.class "text-sm" ] [ text title ]
            ]
        , case maybeRound of
            Nothing ->
                text ""

            Just round ->
                PlaybackControls.view
                    { replay = round.replay
                    , onStart = StartRace
                    , onPause = PauseRace
                    , toReplayMsg = ReplayMsg
                    }
        , columnList maybeRound keys
        ]


{-| The open columns, in strip order, to the right of the playback controls.
Clicking one scrolls the strip along to that column; taking a column away
stays the column's own ✕'s work.

The list is capped and scrolls within itself so a long field of open columns
cannot crowd the controls out of the middle of the header.

-}
columnList : Maybe Shared.LoadedRound -> List Columns.StripKey -> Html Msg
columnList maybeRound keys =
    div
        [ Attributes.class "flex items-center gap-x-1 min-w-0 max-w-[40vw] overflow-x-auto"
        , attribute "data-header-columns" ""
        ]
        (List.map (headerColumn (Maybe.map .snapshot maybeRound)) keys)


headerColumn : Maybe Snapshot -> Columns.StripKey -> Html Msg
headerColumn maybeSnapshot key =
    let
        badge =
            case ( key, maybeSnapshot ) of
                ( Columns.Car carNumber, Just snapshot ) ->
                    Snapshot.get carNumber snapshot
                        |> Maybe.map (\car -> CarNumberBadge.view car.metadata)
                        |> Maybe.withDefault (text "")

                ( Columns.Car carNumber, Nothing ) ->
                    span [ Attributes.class "w-[35px] text-center text-xs font-bold" ] [ text carNumber ]

                ( Columns.ClassColumn class_, _ ) ->
                    classMark class_

                ( Columns.Tracker, _ ) ->
                    mark "TRACK"

                ( Columns.Events, _ ) ->
                    mark "EVENTS"

        mark label =
            div [ Attributes.class "w-[35px] p-1 rounded flex flex-col items-center justify-center border border-border leading-none text-[9px] font-bold" ]
                [ text label ]

        labelText =
            case key of
                Columns.Car carNumber ->
                    "Scroll to car #" ++ carNumber

                Columns.ClassColumn class_ ->
                    "Scroll to the " ++ Class.toString class_ ++ " column"

                Columns.Tracker ->
                    "Scroll to the tracker"

                Columns.Events ->
                    "Scroll to the events column"
    in
    button
        [ Attributes.class "shrink-0 flex items-center p-0.5 rounded cursor-pointer transition-colors hover:bg-accent/40"
        , onClick (FocusColumn key)
        , attribute "aria-label" labelText
        , Attributes.title labelText
        ]
        [ badge ]


{-| A class in the header's list of columns: its name on the bar of its own
colour, at the width the name wants -- no class is called by a number.

Its tile stands as tall as the car's stacked badge's does, so that opening or
closing a car's column cannot move the page under the reader. The class
mark in the standings and in a column's head is the same bar at its own height;
this one is drawn in a tile beside tiles.

-}
classMark : Class -> Html Msg
classMark class_ =
    div
        [ Attributes.class "min-h-[42px] p-1 rounded flex items-center gap-x-1 border border-border leading-none text-[9px] font-bold whitespace-nowrap before:block before:content-[''] before:w-[0.2em] before:h-[1em] before:rounded-[2px] before:[background-color:var(--class-color)]"
        , attribute "style" ("--class-color: " ++ Class.toColor class_ ++ ";")
        ]
        [ text (Class.toString class_) ]


{-| The app ships as a native window without browser back navigation, so the race
list has to be reachable from the page itself.
-}
backLink : Html Msg
backLink =
    a
        [ Route.href Route.Index
        , Attributes.class "inline-flex items-center justify-center size-8 rounded-md cursor-pointer transition-colors hover:bg-accent hover:text-accent-foreground opacity-60 hover:opacity-100"
        , attribute "aria-label" "Back to the race list"
        , Attributes.title "Back to the race list"
        ]
        [ text "←" ]
