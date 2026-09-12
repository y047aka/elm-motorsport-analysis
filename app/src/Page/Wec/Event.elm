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
import Html.Lazy
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Instant as Instant
import Motorsport.Race.Car exposing (Car, CarNumber, Metadata)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Motorsport.Replay as Replay
import Motorsport.Widget.CarCardList as CarCardList
import Motorsport.Widget.CarDetail as CarDetailWidget
import Motorsport.Widget.CarNumberBadge as CarNumberBadge
import Motorsport.Widget.Leaderboard as Leaderboard
import Motorsport.Widget.LiveStandings as LiveStandingsWidget
import Route
import Shared
import Shared.Msg
import Task
import Time
import UI.Notice as Notice
import UI.Shadcn.Card as Card
import UI.Shadcn.ToggleGroup as ToggleGroup
import View exposing (View)
import View.CarDetail as CarDetail
import View.PlaybackControls as PlaybackControls



-- MODEL


type alias Model =
    { mode : Mode
    , standingsTab : StandingsTab
    , leaderboardState : Leaderboard.Model
    , detailCarNumber : Maybe String
    , detailChart : CarDetailWidget.Chart
    , lapHistoryOpen : Bool
    }


type Mode
    = Default
    | Tracker


type StandingsTab
    = LeaderboardTab
    | CardsTab


init : { season : String, event : String } -> ( Model, Effect Msg )
init params =
    ( { mode = Default
      , standingsTab = LeaderboardTab
      , leaderboardState = Leaderboard.init
      , detailCarNumber = Nothing
      , detailChart = CarDetailWidget.GapChart
      , lapHistoryOpen = False
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
    | SelectDetailCar String
    | SelectDetailChart CarDetailWidget.Chart
    | ToggleLapHistory


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

        SelectDetailCar carNumber ->
            ( { m | detailCarNumber = Just carNumber }, Effect.none )

        SelectDetailChart chart ->
            ( { m | detailChart = chart }, Effect.none )

        ToggleLapHistory ->
            ( { m | lapHistoryOpen = not m.lapHistoryOpen }, Effect.none )



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
        maybeRace =
            Shared.race shared
    in
    { title = "Wec"
    , body =
        [ main_
            [ Attributes.class "dark h-full grid grid-rows-[auto_1fr]"
            ]
            [ navigation (headerTitle shared) maybeRace
            , case maybeRace of
                Nothing ->
                    -- Named but not loaded. Nothing is drawn rather than the
                    -- round before it.
                    div [ Attributes.class "row-start-2" ] [ unavailable shared ]

                Just race ->
                    trackerView race.track race.timeline race.snapshot race.replay m
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
        focused =
            focusedCar snapshot m

        layout =
            case m.mode of
                Tracker ->
                    { tracker = "col-start-2 row-start-1 row-span-2"
                    , trackerDetail = TrackerChart.Full
                    , onTracker = ModeChange Default
                    , detail = "col-start-3 row-start-1"
                    }

                _ ->
                    { tracker = "col-start-3 row-start-1"
                    , trackerDetail = TrackerChart.Compact
                    , onTracker = ModeChange Tracker
                    , detail = "col-start-2 row-start-1 row-span-2"
                    }

        detailBody =
            case m.mode of
                Default ->
                    -- A card's content does not shrink below what it holds, so
                    -- the box that scrolls has to be a flex child of the card.
                    [ div [ Attributes.class "flex-1 min-h-0 overflow-y-auto" ]
                        [ Card.content []
                            [ CarDetail.view
                                { activeChart = m.detailChart
                                , onSelectChart = SelectDetailChart
                                , lapHistoryOpen = m.lapHistoryOpen
                                , onToggleLapHistory = ToggleLapHistory
                                }
                                replay.race.cars
                                snapshot
                                focused
                            ]
                        ]
                    ]

                _ ->
                    []
    in
    div
        [ Attributes.class "row-start-2 h-full overflow-y-auto p-[0_10px_10px_10px] flex flex-col gap-2.5" ]
        [ div
            [ Attributes.class "shrink-0 h-full grid grid-cols-[218px_1fr_300px] grid-rows-[300px_minmax(0,1fr)] gap-2.5" ]
            [ div
                [ Attributes.class "col-start-1 row-start-1 row-span-2 h-full overflow-y-hidden" ]
                [ LiveStandingsWidget.view
                    { onSelect = SelectDetailCar
                    , selected = Maybe.map (.metadata >> .carNumber) focused
                    }
                    snapshot
                ]
            , div [ Attributes.class (layout.detail ++ " grid") ] [ Card.card [] detailBody ]
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
        , standingsPanel m.standingsTab m snapshot
        , standingsPopover
        ]


{-| The car the middle of the page is given over to: the one the reader picked,
and until they pick one -- or when the one they picked is not in the field -- the
car at the front of the race.
-}
focusedCar : Snapshot -> Model -> Maybe CarAt
focusedCar snapshot m =
    case m.detailCarNumber |> Maybe.andThen (\carNumber -> Snapshot.get carNumber snapshot) of
        Just car ->
            Just car

        Nothing ->
            Snapshot.leader snapshot


standingsPanel : StandingsTab -> Model -> Snapshot -> Html Msg
standingsPanel tab m snapshot =
    let
        body =
            case tab of
                LeaderboardTab ->
                    Leaderboard.view leaderboardConfig m.leaderboardState snapshot

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

        CarEvent _ (PitIn _) ->
            "Pit In"

        CarEvent _ (PitOut _) ->
            "Pit Out"

        CarEvent _ Retirement ->
            "Retirement"

        CarEvent _ Checkered ->
            "Checkered Flag"


leaderboardConfig : Leaderboard.Config CarAt Msg
leaderboardConfig =
    { toId = .metadata >> .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ Leaderboard.intColumn { label = "", getter = .standing >> .position }
        , Leaderboard.carNumberColumn_Wec { getter = .metadata }
        , Leaderboard.driverAndTeamColumn_Wec
            { getter = \item -> { metadata = item.metadata, currentDriver = item.currentDriver } }
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


navigation : String -> Maybe Shared.Race -> Html Msg
navigation title maybeRace =
    nav
        [ Attributes.class "p-3 grid grid-cols-[auto_1fr] items-center gap-x-10" ]
        [ div [ Attributes.class "flex items-center gap-2 whitespace-nowrap" ]
            [ backLink
            , div [ Attributes.class "text-sm" ] [ text title ]
            ]
        , case maybeRace of
            Nothing ->
                text ""

            Just race ->
                PlaybackControls.view
                    { replay = race.replay
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
