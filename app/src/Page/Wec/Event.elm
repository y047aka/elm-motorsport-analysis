module Page.Wec.Event exposing (Model, Msg, init, subscriptions, update, view)

{-| WEC event page (`/wec/:season/:event`). Migrated from the elm-pages route to
plain TEA. Route parameters are passed into `init` by `Main`.

@docs Model, Msg, init, subscriptions, update, view

-}

import Browser.Events
import DataView
import DataView.Options exposing (PaginationOption(..), SelectingOption(..))
import Effect exposing (Effect)
import Html exposing (Html, a, button, div, main_, nav, text)
import Html.Attributes as Attributes exposing (attribute)
import Html.Events exposing (onClick)
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
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
import UI.Notice as Notice
import UI.Shadcn.Card as Card
import View exposing (View)
import View.CarDetailPopover as CarDetailPopover
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
    = Tracker
    | Events


init : { season : String, event : String } -> ( Model, Effect Msg )
init params =
    ( { mode = Tracker
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
    | ShowCarDetail String
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

        ShowCarDetail carNumber ->
            -- Opening the modal from a standings row click; reset the selection to this single car.
            ( { m | detailCarNumbers = [ carNumber ] }, Effect.none )

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
                    div [ Attributes.class "row-start-2" ] [ unavailable shared ]

                Just race ->
                    case m.mode of
                        Tracker ->
                            trackerView race.track race.snapshot m

                        Events ->
                            RaceEvents.view EventsMsg m.eventsState race.replay
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


trackerView : TrackerChart.Track -> Snapshot -> Model -> Html Msg
trackerView track snapshot m =
    div
        [ Attributes.class "row-start-2 h-full overflow-y-hidden p-[0_10px_10px_10px] grid grid-cols-[300px_1fr_300px] grid-rows-[minmax(0,1fr)_auto] gap-2.5" ]
        [ div
            [ Attributes.class "col-start-1 h-full overflow-y-hidden" ]
            [ LiveStandingsWidget.view
                { snapshot = snapshot

                -- Pass the Msg constructor directly instead of a closure, so the row-level Lazy stays effective
                , onSelectCar = ShowCarDetail
                , popoverTarget = CarDetailPopover.popoverId
                }
            ]
        , div [ Attributes.class "col-start-2 grid" ]
            [ Card.card []
                [ Card.content []
                    [ div
                        [ Attributes.class "h-full grid place-items-center" ]
                        [ TrackerChart.view track snapshot ]
                    ]
                ]
            ]
        , div [ Attributes.class "col-start-3 grid" ] [ Card.card [] [] ]
        , div [ Attributes.class "col-span-full" ]
            [ SelectedCarsStrip.view
                { offset = m.stripOffset
                , onScrollTo = StripScrollTo
                }
                snapshot
            ]
        , CarDetailPopover.view
            { activeChart = m.detailChart
            , onToggleCar = ToggleDetailCar
            , onSelectChart = SelectDetailChart
            }
            snapshot
            m.detailCarNumbers
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
        [ modeButton "Tracker" Tracker (currentMode == Tracker)
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
