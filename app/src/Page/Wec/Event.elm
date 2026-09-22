module Page.Wec.Event exposing (Model, Msg, init, subscriptions, update, view)

{-| WEC event page (`/wec/:season/:event`). Migrated from the elm-pages route to
plain TEA. Route parameters are passed into `init` by `Main`.

@docs Model, Msg, init, subscriptions, update, view

-}

import Browser.Events
import Dict exposing (Dict)
import Effect exposing (Effect)
import Html exposing (Html, a, button, div, main_, nav, span, table, tbody, td, text, tr)
import Html.Attributes as Attributes exposing (attribute)
import Html.Events exposing (onClick)
import Html.Keyed
import Html.Lazy
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Instant as Instant
import Motorsport.Leaderboard as Leaderboard
import Motorsport.Race.Car exposing (Car, CarNumber, Metadata)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Motorsport.Replay as Replay
import Route
import Shared
import Shared.Msg
import Task
import Time
import UI.Notice as Notice
import UI.Shadcn.Card as Card
import UI.Shadcn.ToggleGroup as ToggleGroup
import View exposing (View)
import View.CarCardList as CarCardList
import View.CarDetail as CarDetail
import View.CarNumberBadge as CarNumberBadge
import View.LiveStandings as LiveStandings
import View.PlaybackControls as PlaybackControls



-- MODEL


type alias Model =
    { mode : Mode
    , standingsTab : StandingsTab
    , leaderboardState : Leaderboard.Model
    , selection : List CarNumber
    , detailComparison : CarDetail.Comparison
    , detailPanels : Dict CarNumber CarDetail.Model
    }


{-| What the middle of the page is given over to. The tracker takes the room the
columns need, so the two are never both on show.
-}
type Mode
    = Columns
    | Tracker


type StandingsTab
    = LeaderboardTab
    | CardsTab


init : { season : String, event : String } -> ( Model, Effect Msg )
init params =
    ( { mode = Columns
      , standingsTab = LeaderboardTab
      , leaderboardState = Leaderboard.init
      , selection = []
      , detailComparison = CarDetail.initialComparison
      , detailPanels = Dict.empty
      }
    , Effect.sendSharedMsg (Shared.Msg.FetchJson_Wec { season = params.season, event = params.event })
    )



-- UPDATE


type Msg
    = StartRace
    | PauseRace
    | ModeChange Mode
    | StandingsTabChange StandingsTab
    | ReplayMsg Replay.Msg
    | LeaderboardMsg Leaderboard.Msg
    | ShowDetailCar CarNumber
    | CloseDetailCar CarNumber
    | CarDetailMsg CarNumber CarDetail.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    case msg of
        StartRace ->
            ( m, Task.perform (Replay.Start >> ReplayMsg) Time.now |> Effect.sendCmd )

        PauseRace ->
            ( m, Task.perform (Replay.Pause >> ReplayMsg) Time.now |> Effect.sendCmd )

        ModeChange mode ->
            ( { m | mode = mode }, Effect.none )

        StandingsTabChange tab ->
            ( { m | standingsTab = tab }, Effect.none )

        ReplayMsg replayMsg ->
            ( m, Effect.sendSharedMsg (Shared.Msg.ReplayMsg replayMsg) )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            )

        ShowDetailCar carNumber ->
            ( { m | selection = showCar carNumber m.selection }, Effect.none )

        CloseDetailCar carNumber ->
            ( { m | selection = List.filter ((/=) carNumber) m.selection }, Effect.none )

        CarDetailMsg carNumber detailMsg ->
            let
                next =
                    CarDetail.update detailMsg
                        { comparison = m.detailComparison, panel = panelFor carNumber m }
            in
            ( { m
                | detailComparison = next.comparison
                , detailPanels = Dict.insert carNumber next.panel m.detailPanels
              }
            , Effect.none
            )


{-| A column for `carNumber`, opened at the end. A car that already has one
keeps the one it has rather than being moved to the end.

There is no ceiling on how many. The cell scrolls sideways however many there
are, and the cost of a column the reader has opened is the reader's to weigh --
each draws its own charts on every frame of playback, so a great many of them
running is a great deal of work.

-}
showCar : CarNumber -> List CarNumber -> List CarNumber
showCar carNumber selection =
    if List.member carNumber selection then
        selection

    else
        selection ++ [ carNumber ]


panelFor : CarNumber -> Model -> CarDetail.Model
panelFor carNumber m =
    Dict.get carNumber m.detailPanels |> Maybe.withDefault CarDetail.init



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
    in
    { title = "Wec"
    , body =
        [ main_
            [ Attributes.class "dark h-full grid grid-rows-[auto_1fr]"
            ]
            [ navigation (headerTitle shared) maybeRound
            , case maybeRound of
                Nothing ->
                    -- Named but not loaded. Nothing is drawn rather than the
                    -- round before it.
                    div [ Attributes.class "row-start-2" ] [ unavailable shared ]

                Just round ->
                    trackerView round.track
                        round.timeline
                        round.snapshot
                        round.replay
                        m
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


headerTitle : Shared.Model -> String
headerTitle shared =
    Shared.roundId shared
        |> Maybe.map (\round -> round.name ++ " (" ++ String.fromInt round.season ++ ")")
        |> Maybe.withDefault ""


trackerView : TrackerChart.Track -> Timeline -> Snapshot -> Replay.Model -> Model -> Html Msg
trackerView track timeline snapshot replay m =
    let
        -- Everything the mode decides, read off it once. `shown` is empty under
        -- the tracker, which has the room the columns want. The standings are
        -- handed the selection rather than this, so that going back from the
        -- tracker is going back to what was there.
        layout =
            case m.mode of
                Tracker ->
                    { tracker = "col-start-2 row-start-1 row-span-2"
                    , trackerDetail = TrackerChart.Full
                    , onTracker = ModeChange Columns
                    , detail = "col-start-3 row-start-1"
                    , shown = []
                    }

                Columns ->
                    { tracker = "col-start-3 row-start-1"
                    , trackerDetail = TrackerChart.Compact
                    , onTracker = ModeChange Tracker
                    , detail = "col-start-2 row-start-1 row-span-2"
                    , shown = shownCars snapshot m.selection
                    }
    in
    div
        [ Attributes.class "row-start-2 h-full overflow-y-auto p-[0_10px_10px_10px] flex flex-col gap-2.5" ]
        [ div
            [ Attributes.class "shrink-0 h-full grid grid-cols-[218px_1fr_300px] grid-rows-[300px_minmax(0,1fr)] gap-2.5" ]
            [ div
                [ Attributes.class "col-start-1 row-start-1 row-span-2 h-full overflow-y-hidden" ]
                [ LiveStandings.view
                    { onSelect = ShowDetailCar
                    , picked = m.selection
                    }
                    snapshot
                ]
            , detailColumns layout.detail m replay snapshot layout.shown
            , div
                -- The cell is the only box in the chain whose height is settled,
                -- so a square SVG measured against the width overflows the card.
                [ Attributes.class (layout.tracker ++ " grid place-self-center h-full max-w-full aspect-square cursor-pointer")
                , onClick layout.onTracker
                ]
                [ Card.card []
                    [ Card.content []
                        [ div
                            [ Attributes.class "h-full grid place-items-center" ]
                            [ TrackerChart.view layout.trackerDetail track snapshot ]
                        ]
                    ]
                ]
            , timelinePanel "col-start-3 row-start-2" timeline replay
            ]
        , standingsPanel m.standingsTab m replay snapshot
        , standingsPopover
        ]


{-| The cars the columns are drawn for: the ones the reader picked, in the order
they picked them, and until they have picked any -- or when not one of the ones
they picked is in the field -- the car at the front of each class.

The front of each class rather than the front of the race, because the race is
several races: the car leading the field is leading one of them, and a page that
opened on it alone opened on a third of what was going on. The classes come in
the order the running order puts them in, which is the order their leaders are
in.

-}
shownCars : Snapshot -> List CarNumber -> List CarAt
shownCars snapshot selection =
    case List.filterMap (\carNumber -> Snapshot.get carNumber snapshot) selection of
        [] ->
            Snapshot.toClassList snapshot
                |> List.filterMap (Tuple.second >> List.head)

        picked ->
            picked


{-| The cars on show, side by side. A column is as wide as the panel needs
rather than as wide as the cell can spare, so the third of them is already off
the edge and the cell scrolls sideways to it.

350px. The widest thing in the panel is the comparison's tab row, which wants
302px of the 318 a column of this width hands it -- 16px over, which is the room
to leave for a font that is not the one this was measured in.

The figure has come down as the things that set it have: 440 while the stretch
controls read `Last 1.5h` and every section was a boxed card, 400 until the two
laps stopped sitting abreast, 380 until the first tab stopped reading `Gap to
avg`. The floor under the tab row as it now reads is 335.

One car is drawn in a column too, and not given the cell whole. A panel that
was 880px wide alone and 350 the moment a second car arrived was two panels to
read rather than one, and the wider of them was mostly the room left over: the
figures in it are the same figures, set further apart.

-}
detailColumns : String -> Model -> Replay.Model -> Snapshot -> List CarAt -> Html Msg
detailColumns cell m replay snapshot shown =
    let
        -- Asked of the selection and not of what is drawn: the columns standing
        -- in before a car is picked are not the reader's to close, there being
        -- nothing of theirs to take away.
        card =
            detailCard { closable = List.length m.selection > 1 } m replay snapshot
    in
    case shown of
        [] ->
            -- The tracker has the room, and before any car has turned a lap.
            div [ Attributes.class (cell ++ " grid") ] [ Card.card [] [] ]

        _ ->
            -- Keyed on the car: a column matched by position instead would hand
            -- how far the reader had scrolled it to whichever car moved up into
            -- its place when the one before it was closed.
            Html.Keyed.node "div"
                [ Attributes.class (cell ++ " flex gap-2.5 overflow-x-auto") ]
                (List.map
                    (\car ->
                        ( car.metadata.carNumber
                        , div [ Attributes.class "shrink-0 w-[350px] grid" ] [ card car ]
                        )
                    )
                    shown
                )


detailCard : { closable : Bool } -> Model -> Replay.Model -> Snapshot -> CarAt -> Html Msg
detailCard columns m replay snapshot car =
    let
        carNumber =
            car.metadata.carNumber
    in
    Card.card []
        -- A card's content does not shrink below what it holds, so the box that
        -- scrolls has to be a flex child of the card.
        [ div [ Attributes.class "flex-1 min-h-0 overflow-y-auto" ]
            [ Card.content []
                [ CarDetail.view
                    { toMsg = CarDetailMsg carNumber
                    , onClose =
                        if columns.closable then
                            Just (CloseDetailCar carNumber)

                        else
                            Nothing
                    , comparison = m.detailComparison
                    , showing = panelFor carNumber m
                    }
                    replay.race.cars
                    snapshot
                    car
                ]
            ]
        ]


standingsPanel : StandingsTab -> Model -> Replay.Model -> Snapshot -> Html Msg
standingsPanel tab m replay snapshot =
    let
        body =
            case tab of
                LeaderboardTab ->
                    Leaderboard.view (leaderboardConfig replay.race.cars) m.leaderboardState snapshot

                CardsTab ->
                    CarCardList.view snapshot
    in
    div [ Attributes.class "shrink-0 grid" ]
        [ Card.card []
            [ Card.header []
                [ Card.action [] [ standingsTabs tab ] ]
            , Card.content [] [ body ]
            ]
        ]


standingsTabs : StandingsTab -> Html Msg
standingsTabs current =
    let
        tabItem label tab =
            { label = label
            , active = current == tab
            , disabled = False
            , onSelect = StandingsTabChange tab
            }
    in
    ToggleGroup.view
        { items =
            [ tabItem "Table" LeaderboardTab
            , tabItem "Cards" CardsTab
            ]
        }
        []


{-| The most recent timeline events that have occurred, newest first: when each
happened, whose it was, and what kind of thing it was.
-}
timelinePanel : String -> Timeline -> Replay.Model -> Html Msg
timelinePanel cell timeline replay =
    let
        occurredCount =
            Timeline.countUpTo (Clock.getElapsed replay.playback) timeline
    in
    button
        [ attribute "popovertarget" standingsPopoverId
        , attribute "popovertargetaction" "show"
        , Attributes.class (cell ++ " grid min-h-0 cursor-pointer text-left")
        ]
        [ Card.card []
            [ div [ Attributes.class "flex-1 min-h-0 overflow-y-auto" ]
                [ Card.content []
                    [ table [ Attributes.class "w-full border-collapse text-xs" ]
                        [ Html.Lazy.lazy3 eventRows replay.race.cars timeline occurredCount ]
                    ]
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
        metadataByNumber =
            cars
                |> List.map (\car -> ( car.metadata.carNumber, car.metadata ))
                |> Dict.fromList
    in
    Timeline.latest { upTo = occurredCount, limit = recentEventLimit } timeline
        |> List.map (eventRow metadataByNumber)
        |> tbody []


{-| One row per event: time, whose it was, what it was.
-}
eventRow : Dict CarNumber Metadata -> TimelineEvent -> Html Msg
eventRow metadataByNumber event =
    tr []
        [ td [ Attributes.class "whitespace-nowrap py-0.5 pr-2 tabular-nums text-muted-foreground" ]
            [ text (event.elapsed |> Instant.toDuration |> Duration.toStringToSeconds) ]
        , td [ Attributes.class "w-px py-0.5 pr-2" ]
            [ carBadge metadataByNumber event.eventType ]
        , td [ Attributes.class "py-0.5 text-right" ]
            [ text (eventTypeToString event.eventType) ]
        ]


{-| Whose event this was, badged like the standings badge it sits beside. A race
start belongs to nobody, and a number no car of the field answers to keeps its
bare digits rather than vanishing.
-}
carBadge : Dict CarNumber Metadata -> EventType -> Html Msg
carBadge metadataByNumber eventType =
    case eventType of
        CarEvent carNumber _ ->
            metadataByNumber
                |> Dict.get carNumber
                |> Maybe.map CarNumberBadge.viewRow
                |> Maybe.withDefault (span [] [ text carNumber ])

        RaceStart ->
            text ""


eventTypeToString : EventType -> String
eventTypeToString eventType =
    case eventType of
        RaceStart ->
            "Race Started"

        CarEvent _ Start ->
            "Start"

        CarEvent _ TookLead ->
            "Took the Lead"

        CarEvent _ Retirement ->
            "Retirement"

        CarEvent _ Checkered ->
            "Checkered Flag"


leaderboardConfig : List Car -> Leaderboard.Config CarAt Msg
leaderboardConfig cars =
    let
        -- Worked out once rather than per row: where a car started is fixed for
        -- the whole race, and the table is rebuilt on every frame of playback,
        -- so a scan of the field per row is the same answer found afresh sixty
        -- times a second.
        startPositions : Dict CarNumber Int
        startPositions =
            -- foldr, so that where the source data has two cars under one
            -- number the one running ahead wins, as the scan this replaces did
            -- and as `Snapshot.get` does.
            cars
                |> List.foldr (\car -> Dict.insert car.metadata.carNumber car.startPosition) Dict.empty

        startPositionOf : CarAt -> Maybe Int
        startPositionOf item =
            Dict.get item.metadata.carNumber startPositions
    in
    { toId = .metadata >> .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ Leaderboard.carNumberColumn_Wec { getter = .metadata }
        , Leaderboard.driverAndTeamColumn_Wec
            { getter = \item -> { metadata = item.metadata, currentDriver = item.currentDriver } }
        , Leaderboard.positionChangeColumn
            { getter = \item -> { startPosition = startPositionOf item, position = item.standing.position } }
        , Leaderboard.intColumn { label = "Lap", getter = .standing >> .lapsCompleted }
        , Leaderboard.customColumn
            { label = "Gap"
            , getter = .standing >> .gapToLeader >> Gap.toString
            }
        , Leaderboard.customColumn
            { label = "Interval"
            , getter = .standing >> .intervalToAhead >> Gap.toString
            }
        , Leaderboard.currentLapColumn_Wec { getter = identity }
        , Leaderboard.lastLapColumn_Wec { getter = .lastLap }
        , Leaderboard.bestTimeColumn { getter = .bestLap }
        , Leaderboard.intColumn { label = "Stops", getter = .pitStops }
        ]
    }


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


navigation : String -> Maybe Shared.LoadedRound -> Html Msg
navigation title maybeRound =
    nav
        [ Attributes.class "p-3 grid grid-cols-[auto_1fr] items-center gap-x-10" ]
        [ div [ Attributes.class "flex items-center gap-2 whitespace-nowrap" ]
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
        ]


{-| The app now ships as a native window without browser back navigation, so the
race list has to be reachable from the page itself.
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
