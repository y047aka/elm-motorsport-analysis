module Page.Wec.Event exposing (Model, Msg, init, subscriptions, update, view)

{-| WEC event page (`/wec/:season/:event`). Migrated from the elm-pages route to
plain TEA. Route parameters are passed into `init` by `Main`.

@docs Model, Msg, init, subscriptions, update, view

-}

import Browser.Events
import Compare
import DataView
import DataView.Options exposing (PaginationOption(..), SelectingOption(..))
import Effect exposing (Effect)
import Html exposing (Html, a, button, div, main_, nav, text)
import Html.Attributes as Attributes exposing (attribute)
import Html.Events exposing (onClick)
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Replay as Replay
import Motorsport.Widget.Compare as CompareWidget
import Motorsport.Widget.Leaderboard as Leaderboard exposing (initialSort)
import Motorsport.Widget.LiveStandings as LiveStandingsWidget
import Motorsport.Widget.SelectedCarsStrip as SelectedCarsStrip
import Route
import Shared
import Shared.Msg
import Task
import Time
import UI.Shadcn.Card as Card
import View exposing (View)
import View.CarDetail as CarDetail
import View.PlaybackControls as PlaybackControls
import View.RaceEvents as RaceEvents



-- MODEL


type alias Model =
    { mode : Mode
    , leaderboardState : Leaderboard.Model
    , eventsState : DataView.Model
    , query : String
    , stripOffset : Int
    , detailCarNumbers : List String
    , detailChart : CompareWidget.Chart
    }


type Mode
    = Default
    | Tracker
    | Standings
    | Events


init : { season : String, event : String } -> ( Model, Effect Msg )
init params =
    ( { mode = Default
      , leaderboardState = initialSort "Position"
      , eventsState =
            DataView.init "Time"
                (DataView.Options.defaultOptions
                    |> (\options_ ->
                            { options_
                                | selecting = NoSelecting
                                , pagination = NoPagination
                            }
                       )
                )
      , query = ""
      , stripOffset = 0
      , detailCarNumbers = []
      , detailChart = CompareWidget.GapChart
      }
    , Effect.sendSharedMsg (Shared.Msg.FetchJson_Wec { season = params.season, event = params.event })
    )



-- UPDATE


type Msg
    = StartRace
    | PauseRace
    | ModeChange Mode
    | ReplayMsg Replay.Msg
    | LeaderboardMsg Leaderboard.Msg
    | EventsMsg DataView.Msg
    | StripScrollTo Int
    | ToggleDetailCar String
    | SelectDetailChart CompareWidget.Chart


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    case msg of
        StartRace ->
            ( m, Task.perform (Replay.Start >> ReplayMsg) Time.now |> Effect.sendCmd )

        PauseRace ->
            ( m, Task.perform (Replay.Pause >> ReplayMsg) Time.now |> Effect.sendCmd )

        ModeChange mode ->
            ( { m | mode = mode }, Effect.none )

        ReplayMsg replayMsg ->
            ( m, Effect.sendSharedMsg (Shared.Msg.ReplayMsg replayMsg) )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            )

        EventsMsg eventsMsg ->
            ( { m | eventsState = DataView.update eventsMsg m.eventsState }
            , Effect.none
            )

        StripScrollTo offset ->
            ( { m | stripOffset = max 0 offset }, Effect.none )

        ToggleDetailCar carNumber ->
            -- In-modal selector; toggle selection up to a maximum of 3 cars.
            let
                next =
                    if List.member carNumber m.detailCarNumbers then
                        List.filter ((/=) carNumber) m.detailCarNumbers

                    else
                        List.take 3 (m.detailCarNumbers ++ [ carNumber ])
            in
            ( { m | detailCarNumbers = next }, Effect.none )

        SelectDetailChart chart ->
            ( { m | detailChart = chart }, Effect.none )



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
            [ navigation (headerTitle shared) maybeRace m.mode
            , case maybeRace of
                Nothing ->
                    -- Named but not loaded. Nothing is drawn rather than the
                    -- round before it.
                    div [ Attributes.class "row-start-2" ] []

                Just race ->
                    case m.mode of
                        Default ->
                            trackerView race.track race.snapshot m

                        Tracker ->
                            trackerView race.track race.snapshot m

                        Standings ->
                            trackerView race.track race.snapshot m

                        Events ->
                            RaceEvents.view EventsMsg m.eventsState race.replay
            ]
        ]
    }


headerTitle : Shared.Model -> String
headerTitle shared =
    Shared.roundId shared
        |> Maybe.map (\round -> round.name ++ " (" ++ String.fromInt round.season ++ ")")
        |> Maybe.withDefault ""


trackerView : TrackerChart.Track -> Snapshot -> Model -> Html Msg
trackerView track snapshot m =
    let
        layout =
            case m.mode of
                Tracker ->
                    { tracker = "col-start-2 row-start-1 row-span-2"
                    , trackerDetail = TrackerChart.Full
                    , onTracker = ModeChange Default
                    , detail = "col-start-3 row-start-1"
                    , leaderboard = Nothing
                    , spare = Just "col-start-3 row-start-2"
                    }

                Standings ->
                    { tracker = "col-start-3 row-start-1"
                    , trackerDetail = TrackerChart.Compact
                    , onTracker = ModeChange Tracker
                    , detail = "col-start-3 row-start-2"
                    , leaderboard = Just "col-start-2 row-start-1 row-span-2"
                    , spare = Nothing
                    }

                _ ->
                    { tracker = "col-start-3 row-start-1"
                    , trackerDetail = TrackerChart.Compact
                    , onTracker = ModeChange Tracker
                    , detail = "col-start-2 row-start-1 row-span-2"
                    , leaderboard = Nothing
                    , spare = Just "col-start-3 row-start-2"
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
                                , onToggleCar = ToggleDetailCar
                                , onSelectChart = SelectDetailChart
                                }
                                snapshot
                                m.detailCarNumbers
                            ]
                        ]
                    ]

                _ ->
                    []
    in
    div
        [ Attributes.class "row-start-2 h-full overflow-y-hidden p-[0_10px_10px_10px] grid grid-cols-[300px_1fr_300px] grid-rows-[300px_minmax(0,1fr)_auto] gap-2.5" ]
        ([ div
            [ Attributes.class "col-start-1 row-start-1 row-span-3 h-full overflow-y-hidden cursor-pointer"
            , onClick (ModeChange Standings)
            ]
            [ LiveStandingsWidget.view snapshot ]
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
         ]
            ++ List.filterMap identity
                [ Maybe.map (leaderboardCell m.leaderboardState snapshot) layout.leaderboard
                , Maybe.map sparePanel layout.spare
                ]
            ++ [ div [ Attributes.class "col-start-2 col-span-2 row-start-3" ]
                    [ SelectedCarsStrip.view
                        { offset = m.stripOffset
                        , onScrollTo = StripScrollTo
                        }
                        snapshot
                    ]
               , standingsPopover
               ]
        )


sparePanel : String -> Html Msg
sparePanel cell =
    button
        [ attribute "popovertarget" standingsPopoverId
        , attribute "popovertargetaction" "show"
        , Attributes.class (cell ++ " grid cursor-pointer text-left")
        ]
        [ Card.card [] [] ]


leaderboardCell : Leaderboard.Model -> Snapshot -> String -> Html Msg
leaderboardCell leaderboardState snapshot cell =
    div [ Attributes.class (cell ++ " grid min-h-0") ]
        [ Card.card []
            -- A card's content does not shrink below what it holds, so
            -- the box that scrolls has to be a flex child of the card.
            [ div [ Attributes.class "flex-1 min-h-0 overflow-y-auto" ]
                [ Card.content []
                    [ Leaderboard.view leaderboardConfig leaderboardState snapshot ]
                ]
            ]
        ]


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
            , sorter = Compare.by (.standing >> .position)
            }
        , Leaderboard.customColumn
            { label = "Interval"
            , getter = .standing >> .intervalToAhead >> Gap.toString
            , sorter = Compare.by (.standing >> .position)
            }
        , Leaderboard.currentLapColumn_Wec
            { getter = identity
            , sorter = Compare.by (.currentLap >> .elapsed)
            }
        , Leaderboard.lastLapColumn_Wec
            { getter = .lastLap
            , sorter = Compare.by (.lastLap >> lastLapTime)
            }
        , Leaderboard.bestTimeColumn { getter = .bestLap }
        ]
    }


lastLapTime : Snapshot.LastLap -> Duration
lastLapTime lastLap =
    case lastLap of
        Snapshot.Completed { rated } ->
            rated |> Maybe.map .time |> Maybe.withDefault 0

        Snapshot.NoLapYet ->
            0


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


navigation : String -> Maybe Shared.Race -> Mode -> Html Msg
navigation title maybeRace currentMode =
    nav
        [ Attributes.class "p-3 grid grid-cols-[auto_1fr_auto] items-center gap-x-10" ]
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
        , viewModeSelector currentMode
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


viewModeSelector : Mode -> Html Msg
viewModeSelector currentMode =
    div [ Attributes.class "inline-flex" ]
        [ modeButton "Default" Default (currentMode == Default)
        , modeButton "Tracker" Tracker (currentMode == Tracker)
        , modeButton "Standings" Standings (currentMode == Standings)
        , modeButton "Events" Events (currentMode == Events)
        ]


modeButton : String -> Mode -> Bool -> Html Msg
modeButton label mode isActive =
    joinButton label isActive (ModeChange mode)


joinButton : String -> Bool -> Msg -> Html Msg
joinButton label isActive msg =
    button
        [ onClick msg
        , Attributes.class
            ("inline-flex h-8 items-center justify-center border border-border px-3 text-sm font-medium cursor-pointer transition-colors -ml-px first:ml-0 first:rounded-l-md last:rounded-r-md"
                ++ (if isActive then
                        " bg-primary text-primary-foreground border-primary"

                    else
                        " bg-accent/40 text-foreground hover:bg-accent/70"
                   )
            )
        ]
        [ text label ]
