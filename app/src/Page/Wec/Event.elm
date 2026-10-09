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
import Internal.DataView as DataView
import Internal.DataView.Options exposing (FilteringOption(..), Options, PaginationOption(..), SelectingOption(..), SortingOption(..))
import Json.Decode as Decode
import List.Extra
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Instant as Instant
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
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
import UI.Shadcn.Button as Button
import UI.Shadcn.Card as Card
import UI.Shadcn.ToggleGroup as ToggleGroup
import View exposing (View)
import View.CarCardList as CarCardList
import View.CarDetail as CarDetail
import View.CarDetail.Header as Header
import View.CarNumberBadge as CarNumberBadge
import View.ClassColumn as ClassColumn
import View.ClassMark as ClassMark
import View.LiveStandings as LiveStandings
import View.PitLane as PitLane
import View.PlaybackControls as PlaybackControls



-- MODEL


type alias Model =
    { pane : Pane
    , strip : Columns.Model
    , bottomTab : BottomTab
    , timelineTable : DataView.Model
    , comparison : CarDetail.Comparison
    , standings : Resize.Model
    }


standingsFence : Resize.Fence
standingsFence =
    { min = LiveStandings.minWidth
    , max = LiveStandings.maxWidth
    , step = 20
    }


{-| The page's right-hand pane: the tracker the reader adds a column of, and
the timeline.
-}
type Pane
    = Shown
    | Hidden


togglePane : Pane -> Pane
togglePane pane =
    case pane of
        Shown ->
            Hidden

        Hidden ->
            Shown


type BottomTab
    = CardsTab
    | EventsTab


init : { season : String, event : String } -> ( Model, Effect Msg )
init params =
    ( { pane = Shown
      , strip = Columns.init
      , bottomTab = CardsTab
      , timelineTable = DataView.init "timeline-events" timelineTableOptions
      , comparison = CarDetail.initialComparison
      , standings = Resize.init LiveStandings.width
      }
    , Effect.sendSharedMsg (Shared.Msg.FetchJson_Wec { season = params.season, event = params.event })
    )



-- UPDATE


type Msg
    = StartRace
    | PauseRace
    | TogglePane
    | FocusColumn Columns.StripKey
    | ColumnsMsg Columns.Msg
    | ResizeMsg Resize.Msg
    | BottomTabChange BottomTab
    | TimelineTableMsg DataView.Msg
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

        TogglePane ->
            ( { m | pane = togglePane m.pane }, Effect.none )

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

        BottomTabChange tab ->
            ( { m | bottomTab = tab }, Effect.none )

        TimelineTableMsg timelineMsg ->
            ( { m | timelineTable = DataView.update timelineMsg m.timelineTable }, Effect.none )

        ReplayMsg replayMsg ->
            ( m, Effect.sendSharedMsg (Shared.Msg.ReplayMsg replayMsg) )

        CarDetailMsg detailMsg ->
            ( { m | comparison = CarDetail.update detailMsg m.comparison }, Effect.none )


{-| The field is read at the moment of the message, never kept: the strip's
update takes it as an argument and the stand-ins are off it.
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
            [ navigation m.pane keys (headerTitle shared) maybeRound
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
a column: playback re-reads the order every frame, and each reading costs
the field walk the stand-ins are resolved against.
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
the one thing that takes it away; the body answers to no click.

The card splits two-to-one: the drawing fills the top two thirds, and the
cars in the pit lane -- standing in their boxes or already driving away --
fill the bottom third, scrolling once they outnumber it.

It carries `data-tracker-column`, which the visual tests locate it by.

-}
trackerCard : Bool -> Bool -> TrackerChart.Track -> Snapshot -> Html Msg
trackerCard several held track snapshot =
    Card.card [ attribute "data-tracker-column" "" ]
        [ div
            [ Attributes.class "flex-1 min-h-0 grid grid-rows-[minmax(0,2fr)_minmax(0,1fr)]"
            ]
            [ Card.content []
                [ div [ Attributes.class "relative h-full w-full grid place-items-center" ]
                    [ TrackerChart.view TrackerChart.Full track snapshot
                    , div [ Attributes.class "absolute top-0 right-0 flex items-start gap-x-1" ]
                        ((if several then
                            [ columnGrip held Columns.Tracker ]

                          else
                            []
                         )
                            ++ [ Header.closeButton (ColumnsMsg (Columns.ShowTracker False)) ]
                        )
                    ]
                ]
            , Card.content [] [ PitLane.view snapshot ]
            ]
        ]


mainGrid : Shared.LoadedRound -> List Columns.StripKey -> Model -> Html Msg
mainGrid round keys m =
    let
        snapshot =
            round.snapshot

        replay =
            round.replay

        gridCells =
            standingsCell keys m snapshot replay.race.cars
                :: columnStrip "col-start-2 row-start-1 row-span-2" round.track round.timeline keys m replay snapshot
                :: paneCells m.pane round.track snapshot round.fieldEvents replay
    in
    div
        [ Attributes.class "row-start-2 h-full overflow-y-auto p-[0_10px_10px_10px] flex flex-col gap-2.5" ]
        [ div
            [ Attributes.class
                ("shrink-0 h-full grid " ++ gridColumns m.pane ++ " grid-rows-[300px_minmax(0,1fr)] gap-2.5")
            ]
            gridCells
        , bottomPanel m.bottomTab m.timelineTable round.replay.race.cars round.timeline snapshot
        , standingsPopover
        , div [ attribute "aria-live" "polite", Attributes.class "sr-only" ] [ text m.strip.announcement ]
        ]


{-| Three tracks: the standings, the strip, and the tracker pane once it is
shown.

Each spelling is written whole: Tailwind generates a class only from a string
it finds intact in the source, so one assembled from fragments — a width here,
a suffix there — silently ships no `grid-template-columns` at all, and every
track sizes to its content.

-}
gridColumns : Pane -> String
gridColumns pane =
    case pane of
        Shown ->
            "grid-cols-[auto_1fr_270px]"

        Hidden ->
            "grid-cols-[auto_1fr]"


{-| The live standings, standing to the left of the strip rather than as one
of its columns, and a grip along their right edge to drag them wider or
narrower. The grip is drawn over the card's edge -- the card's own `class`
is the custom element's -- and the column track is `auto`, so the strip
gains and loses the width as the drag goes on.
-}
standingsCell : List Columns.StripKey -> Model -> Snapshot -> List Car -> Html Msg
standingsCell keys m snapshot cars =
    let
        startPositions =
            -- foldr, so that where the source data has two cars under one
            -- number the one running ahead wins, as in `Snapshot.get`.
            cars
                |> List.foldr (\car -> Dict.insert car.metadata.carNumber car.startPosition) Dict.empty
    in
    div
        [ Attributes.class "col-start-1 row-start-1 row-span-2 min-h-0 grid relative" ]
        [ LiveStandings.view
            { onSelect = pickCar
            , withColumns = List.map (.metadata >> .carNumber) (Columns.carsIn snapshot keys)
            , openColumn = openColumn keys
            , width = m.standings.width
            , startPosition = \number -> Dict.get number startPositions
            }
            snapshot
        , div [ Attributes.class "absolute right-0 top-0 h-full z-10" ]
            [ Html.map ResizeMsg (Resize.grip m.standings) ]
        ]


{-| A car picked -- from the standings, or from the class's column it is running
in. Whole and top-level, because both panels thunk their rows and compare this by
reference: a composition built per render redraws every row on every frame.

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
standing, and the column called for where the reader has closed it. The class's
name in the standings is where a closed column is asked for again, since it is
where the class's cars are listed already.
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


{-| The tracker and the timeline, or nothing once the pane is hidden.

The tracker's box is settled the way the tracker column settles its own --
row, grow, row -- because the card's content has no height of its own to
give a drawing a percentage of: a drawing sized only by its viewBox's aspect,
and a tall circuit's is very tall, runs past the card's border instead of
inside it.

-}
paneCells : Pane -> TrackerChart.Track -> Snapshot -> Timeline -> Replay.Model -> List (Html Msg)
paneCells pane track snapshot fieldEvents replay =
    case pane of
        Hidden ->
            []

        Shown ->
            [ div
                [ Attributes.class "col-start-3 row-start-1 h-full grid grid-rows-[minmax(0,1fr)] cursor-pointer"
                , attribute "data-tracker-pane" ""
                , onClick (ColumnsMsg (Columns.ShowTracker True))
                ]
                [ Card.card []
                    [ div
                        [ Attributes.class "flex-1 min-h-0 grid grid-rows-[minmax(0,1fr)]" ]
                        [ Card.content []
                            [ div
                                [ Attributes.class "relative h-full w-full grid place-items-center" ]
                                [ TrackerChart.view TrackerChart.Compact track snapshot ]
                            ]
                        ]
                    ]
                ]
            , timelinePanel "col-start-3 row-start-2" fieldEvents replay
            ]


columnStrip : String -> TrackerChart.Track -> Timeline -> List Columns.StripKey -> Model -> Replay.Model -> Snapshot -> Html Msg
columnStrip cell track timeline keys m replay snapshot =
    let
        several =
            List.length keys > 1

        placements =
            Columns.placements (always Columns.width) (Columns.carrying m.strip) keys

        standing =
            List.map (\car -> car.metadata.carNumber) (Columns.carsIn snapshot keys)

        columnCell key placement =
            case key of
                Columns.Car carNumber ->
                    stripColumn (Columns.keyName key)
                        Columns.width
                        placement
                        (Snapshot.get carNumber snapshot
                            |> Maybe.map
                                (\car ->
                                    Html.Lazy.lazy6 (carCard several) timeline (Columns.isCarried placement) m.comparison replay.race.cars snapshot car
                                )
                            |> Maybe.withDefault (text "")
                        )

                Columns.ClassColumn class_ ->
                    stripColumn (Columns.keyName key)
                        Columns.width
                        placement
                        (classColumn several standing (Columns.isCarried placement) snapshot class_)

                Columns.Tracker ->
                    stripColumn (Columns.keyName key)
                        Columns.width
                        placement
                        (trackerCard several (Columns.isCarried placement) track snapshot)
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


{-| One class of the field, which is what the strip opens with: the class's cars
in running order, each against the class-mate ahead of it.

A row picks the car it names, and that car's own column opens beside the class's.
A row whose car is up already is drawn marked, and the strip goes to that column
instead of opening a second one.

-}
classColumn : Bool -> List CarNumber -> Bool -> Snapshot -> Class -> Html Msg
classColumn several standing held snapshot class_ =
    ClassColumn.view
        { onSelect = pickCar
        , onReveal = revealCar
        , withColumns = standing
        , onClose =
            if several then
                Just (ColumnsMsg (Columns.Close (Columns.ClassColumn class_)))

            else
                Nothing
        , grip =
            if several then
                Just (columnGrip held (Columns.ClassColumn class_))

            else
                Nothing
        }
        snapshot
        class_


carCard : Bool -> Timeline -> Bool -> CarDetail.Comparison -> List Car -> Snapshot -> CarAt -> Html Msg
carCard several timeline held comparison cars snapshot car =
    let
        carNumber =
            car.metadata.carNumber
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
                    , onClose =
                        if several then
                            Just (ColumnsMsg (Columns.Close (Columns.Car carNumber)))

                        else
                            Nothing
                    , grip =
                        if several then
                            Just (columnGrip held (Columns.Car carNumber))

                        else
                            Nothing
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


bottomPanel : BottomTab -> DataView.Model -> List Car -> Timeline -> Snapshot -> Html Msg
bottomPanel tab table cars timeline snapshot =
    let
        body =
            case tab of
                CardsTab ->
                    CarCardList.view snapshot

                EventsTab ->
                    DataView.view (timelineTableConfig cars) table (List.indexedMap Tuple.pair (Timeline.toList timeline))
    in
    div [ Attributes.class "shrink-0 grid" ]
        [ Card.card []
            [ Card.header []
                [ Card.action [] [ bottomTabs tab ] ]
            , Card.content [] [ body ]
            ]
        ]


bottomTabs : BottomTab -> Html Msg
bottomTabs current =
    let
        tabItem label tab =
            { label = label
            , active = current == tab
            , disabled = False
            , onSelect = BottomTabChange tab
            }
    in
    ToggleGroup.view
        { items =
            [ tabItem "Cards" CardsTab
            , tabItem "Events" EventsTab
            ]
        }
        []


timelineTableOptions : Options
timelineTableOptions =
    { sorting = Sorting
    , filtering = Filtering
    , selecting = NoSelecting
    , pagination = Pagination 15
    }


{-| The events table, configured on the DataView directly rather than through
the `Leaderboard`: these are events, not the field, and what the `Leaderboard`
draws belongs to a lap. The car column is the right-hand timeline's own
`carBadge`, so a number reads the same on both halves of the page.

Rows are keyed by their place in the timeline — a number no two events share,
where a moment's milliseconds and its words are the same for any two events
of one kind at one instant, which the file can hold.

-}
timelineTableConfig : List Car -> DataView.Config ( Int, TimelineEvent ) Msg
timelineTableConfig cars =
    let
        carsByNumber =
            List.foldr (\car -> Dict.insert car.metadata.carNumber car) Dict.empty cars

        eventOf : ( Int, TimelineEvent ) -> TimelineEvent
        eventOf =
            Tuple.second

        carOf : ( Int, TimelineEvent ) -> Maybe Car
        carOf row =
            case (eventOf row).eventType of
                CarEvent carNumber _ ->
                    Dict.get carNumber carsByNumber

                _ ->
                    Nothing

        classOf : ( Int, TimelineEvent ) -> Maybe String
        classOf row =
            carOf row
                |> Maybe.map (.metadata >> .class >> Class.toString)

        number : ( Int, TimelineEvent ) -> Maybe String
        number row =
            carOf row
                |> Maybe.map (.metadata >> .carNumber)

        elapsed : ( Int, TimelineEvent ) -> Duration
        elapsed row =
            Instant.toDuration (eventOf row).elapsed
    in
    { toId = Tuple.first >> String.fromInt
    , toMsg = TimelineTableMsg
    , columns =
        [ DataView.customColumn
            { label = "Time"
            , getter = elapsed >> Duration.toStringToSeconds
            , sorter = \a b -> compare (elapsed a) (elapsed b)
            }
        , DataView.veryCustomColumn
            { label = "Car"
            , getter = \row -> carBadge (carOf row) (eventOf row).eventType
            , sorter = \a b -> compare (Maybe.withDefault "" (number a)) (Maybe.withDefault "" (number b))
            }
        , DataView.customColumn
            { label = "Class"
            , getter = classOf >> Maybe.withDefault ""
            , sorter = \a b -> compare (Maybe.withDefault "" (classOf a)) (Maybe.withDefault "" (classOf b))
            }
        , DataView.customColumn
            { label = "Event"
            , getter = eventOf >> .eventType >> TimelineEvent.describe
            , sorter = \a b -> compare (TimelineEvent.describe (eventOf a).eventType) (TimelineEvent.describe (eventOf b).eventType)
            }
        ]
    }


{-| The most recent events the field draws, newest first: when each happened,
whose it was, and what kind of thing it was.

`recentEventLimit` counts the rows here, not the round's events.

-}
timelinePanel : String -> Timeline -> Replay.Model -> Html Msg
timelinePanel cell fieldEvents replay =
    let
        occurredCount =
            Timeline.countUpTo (Clock.getElapsed replay.playback) fieldEvents
    in
    button
        [ attribute "popovertarget" standingsPopoverId
        , attribute "popovertargetaction" "show"
        , Attributes.class (cell ++ " grid min-h-0 cursor-pointer text-left")
        ]
        [ Card.card []
            [ div [ Attributes.class "flex-1 min-h-0 overflow-y-auto" ]
                [ Card.content []
                    [ Html.Lazy.lazy3 eventRows replay.race.cars fieldEvents occurredCount ]
                ]
            ]
        ]


recentEventLimit : Int
recentEventLimit =
    100


{-| The panel's rows, rebuilt only when an event arrives. A thunk's arguments are
compared by `===`, so every one of these is held to something that survives a
frame: the cars and the timeline never move under playback, and the count is a
number. Anything frame-made passed instead -- a snapshot, or the cut list itself
-- is a fresh reference on every frame and misses.
-}
eventRows : List Car -> Timeline -> Int -> Html Msg
eventRows cars timeline occurredCount =
    let
        carsByNumber =
            cars
                |> List.map (\car -> ( car.metadata.carNumber, car ))
                |> Dict.fromList
    in
    Timeline.latest { upTo = occurredCount, limit = recentEventLimit } timeline
        |> List.map (eventRow carsByNumber)
        |> div [ Attributes.class "grid grid-cols-[auto_auto_1fr_auto] gap-x-2 text-xs" ]


{-| A row is one line as tall as the badge: the `1.375rem` is
`CarNumberBadge.viewRow`'s height, and moves with it.
-}
eventRow : Dict CarNumber Car -> TimelineEvent -> Html Msg
eventRow carsByNumber event =
    let
        car =
            case event.eventType of
                CarEvent carNumber _ ->
                    Dict.get carNumber carsByNumber

                _ ->
                    Nothing

        cell classes children =
            div [ Attributes.class classes ] children

        name =
            case ( event.eventType, car |> Maybe.andThen (\item -> TimelineEvent.runningLap item event) |> Maybe.andThen .time ) of
                ( CarEvent _ FastestLap, Just time ) ->
                    Duration.toString time ++ " (Fastest)"

                _ ->
                    TimelineEvent.describe event.eventType
    in
    div [ Attributes.class "col-span-4 grid grid-cols-subgrid items-center py-0.5" ]
        [ cell "" [ car |> Maybe.map (.metadata >> ClassMark.view) |> Maybe.withDefault (text "") ]
        , cell "" [ carBadge car event.eventType ]
        , cell "" [ text name ]
        , cell "whitespace-nowrap text-right tabular-nums text-muted-foreground"
            [ text (event.elapsed |> Instant.toDuration |> Duration.toStringToSeconds) ]
        ]


{-| An event of the whole field's has no badge, and a number no car of the field
answers to keeps its bare digits rather than vanishing.
-}
carBadge : Maybe Car -> EventType -> Html Msg
carBadge car eventType =
    case ( car, eventType ) of
        ( Just { metadata }, _ ) ->
            CarNumberBadge.viewRow metadata

        ( Nothing, CarEvent carNumber _ ) ->
            span [] [ text carNumber ]

        ( Nothing, _ ) ->
            text ""


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


navigation : Pane -> List Columns.StripKey -> String -> Maybe Shared.LoadedRound -> Html Msg
navigation pane keys title maybeRound =
    nav
        [ Attributes.class "p-3 grid grid-cols-[auto_1fr_auto_auto] items-center gap-x-10" ]
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
        , paneToggle pane
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
    in
    button
        [ Attributes.class "shrink-0 flex items-center p-0.5 rounded cursor-pointer transition-colors hover:bg-accent/40"
        , onClick (FocusColumn key)
        , attribute "aria-label" labelText
        , Attributes.title labelText
        ]
        [ badge ]


{-| A class in the header's list of columns: its name on the bar of its own
colour, which is the width the name wants rather than the car number's tile, since
no class is called by a number.

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


{-| The arrows point at the edge the pane lives on.
-}
paneToggle : Pane -> Html Msg
paneToggle pane =
    let
        verb =
            case pane of
                Shown ->
                    "Hide"

                Hidden ->
                    "Show"

        glyph =
            case pane of
                Shown ->
                    "»"

                Hidden ->
                    "«"
    in
    Button.view
        { label = glyph
        , variant = Button.Ghost
        , size = Button.Icon
        , shape = Button.Circle
        , disabled = False
        , onPress = TogglePane
        }
        [ attribute "aria-label" (verb ++ " the tracker and timeline")
        , Attributes.title (verb ++ " the tracker and timeline")
        ]


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
