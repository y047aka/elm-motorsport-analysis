module Route.Wec.Season_.Event_ exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import Browser.Events
import Css exposing (..)
import Data.Series.EventSummary exposing (EventSummary)
import DataView
import DataView.Options exposing (PaginationOption(..), SelectingOption(..))
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html.Styled as Html exposing (Html, button, div, input, main_, nav, text)
import Html.Styled.Attributes as Attributes exposing (attribute, css, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock as Clock exposing (State(..))
import Motorsport.Duration as Duration
import Motorsport.Leaderboard as Leaderboard exposing (initialSort)
import Motorsport.RaceControl as RaceControl
import Motorsport.Standings as Standings
import Motorsport.TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Motorsport.Utils exposing (compareBy)
import Motorsport.Widget.Compare as CompareWidget
import Motorsport.Widget.LiveStandings as LiveStandingsWidget
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatefulRoute)
import Shared
import String exposing (dropRight)
import Task
import Time
import UrlPath exposing (UrlPath)
import View exposing (View)


type alias RouteParams =
    { season : String, event : String }


route : StatefulRoute RouteParams Data ActionData Model Msg
route =
    RouteBuilder.preRender
        { head = \_ -> []
        , pages = pages
        , data = data
        }
        |> RouteBuilder.buildWithSharedState
            { init = init
            , update = update
            , subscriptions = subscriptions
            , view = view
            }


pages : BackendTask FatalError (List RouteParams)
pages =
    BackendTask.succeed
        [ { season = "2024", event = "le_mans_24h" }
        , { season = "2024", event = "fuji_6h" }
        , { season = "2024", event = "bahrain_8h" }
        , { season = "2025", event = "qatar_1812km" }
        , { season = "2025", event = "imola_6h" }
        , { season = "2025", event = "spa_6h" }
        , { season = "2025", event = "le_mans_24h" }
        , { season = "2025", event = "sao_paulo_6h" }
        , { season = "2025", event = "cota_6h" }
        , { season = "2025", event = "fuji_6h" }
        ]



-- MODEL


type alias Model =
    { mode : Mode
    , leaderboardState : Leaderboard.Model
    , eventsState : DataView.Model
    , query : String
    , compare : CompareWidget.Model
    }


type Mode
    = Tracker
    | Events


init :
    App Data ActionData RouteParams
    -> Shared.Model
    -> ( Model, Effect Msg )
init app shared =
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
      , compare = CompareWidget.init
      }
    , Effect.fromCmd
        (Task.succeed (Shared.FetchJson_Wec { season = app.routeParams.season, event = app.routeParams.event })
            |> Task.perform SharedMsg
        )
    )



-- UPDATE


type Msg
    = SharedMsg Shared.Msg
    | StartRace
    | PauseRace
    | ModeChange Mode
    | RaceControlMsg RaceControl.Msg
    | LeaderboardMsg Leaderboard.Msg
    | EventsMsg DataView.Msg
    | CompareWidgetMsg CompareWidget.Msg


update :
    App Data ActionData RouteParams
    -> Shared.Model
    -> Msg
    -> Model
    -> ( Model, Effect Msg, Maybe Shared.Msg )
update app shared msg m =
    case msg of
        SharedMsg sharedMsg ->
            ( m, Effect.none, Just sharedMsg )

        StartRace ->
            ( m, Task.perform (RaceControl.Start >> RaceControlMsg) Time.now |> Effect.fromCmd, Nothing )

        PauseRace ->
            ( m, Task.perform (RaceControl.Pause >> RaceControlMsg) Time.now |> Effect.fromCmd, Nothing )

        ModeChange mode ->
            ( { m | mode = mode }, Effect.none, Nothing )

        RaceControlMsg raceControlMsg ->
            ( m, Effect.none, Just (Shared.RaceControlMsg raceControlMsg) )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            , Nothing
            )

        EventsMsg eventsMsg ->
            ( { m | eventsState = DataView.update eventsMsg m.eventsState }
            , Effect.none
            , Nothing
            )

        CompareWidgetMsg compareMsg ->
            ( { m | compare = CompareWidget.update compareMsg m.compare }
            , Effect.none
            , Nothing
            )



-- SUBSCRIPTIONS


subscriptions : RouteParams -> UrlPath -> Shared.Model -> Model -> Sub Msg
subscriptions routeParams path shared model =
    case shared.raceControl.clock.state of
        Started _ _ ->
            Browser.Events.onAnimationFrame (RaceControl.Tick >> RaceControlMsg)

        _ ->
            Sub.none



-- DATA


type alias Data =
    {}


type alias ActionData =
    {}


data : RouteParams -> BackendTask FatalError Data
data routeParams =
    BackendTask.succeed {}



-- VIEW


view :
    App Data ActionData RouteParams
    -> Shared.Model
    -> Model
    -> View (PagesMsg Msg)
view app { eventSummary, analysis, raceControl } m =
    View.map PagesMsg.fromMsg
        { title = "Wec"
        , body =
            [ Html.node "style"
                []
                [ text """
                    @keyframes slideUp {
                        from {
                            transform: translateY(100%);
                        }
                        to {
                            transform: translateY(0);
                        }
                    }
                """ ]
            , main_
                [ attribute "data-theme" "forest"
                , css
                    [ height (pct 100)
                    , property "display" "grid"
                    , property "grid-template-rows" "auto 1fr"
                    ]
                ]
                [ navigation eventSummary raceControl m.mode
                , let
                    standings =
                        Standings.init
                            { elapsed = Clock.getElapsed raceControl.clock
                            , lapCount = raceControl.lapCount
                            , cars = raceControl.cars
                            , fastestLapTime = analysis.fastestLapTime
                            }

                    compareProps =
                        { eventSummary = eventSummary
                        , standings = standings
                        , clock = raceControl.clock
                        , analysis = analysis
                        }
                  in
                  case m.mode of
                    Tracker ->
                        div
                            [ css
                                [ height (pct 100)
                                , overflowY hidden
                                , padding4 (px 0) (px 10) (px 10) (px 10)
                                , property "display" "grid"
                                , property "grid-template-columns" "300px 1fr 300px"
                                , property "grid-template-rows" "minmax(0, 1fr) auto auto"
                                , property "row-gap" "10px"
                                , property "column-gap" "10px"
                                ]
                            ]
                            [ div
                                [ css
                                    [ property "grid-row" "1 / 3"
                                    , property "grid-column" "1"
                                    , property "height" "100%"
                                    ]
                                ]
                                [ LiveStandingsWidget.view
                                    { eventSummary = eventSummary
                                    , standings = standings
                                    , onSelectCar = (\item -> CompareWidget.ToggleCar item.metadata.carNumber) >> CompareWidgetMsg
                                    }
                                ]
                            , div
                                [ Attributes.class "card bg-base-200 overflow-hidden p-4"
                                , css
                                    [ property "grid-row" "1"
                                    , property "grid-column" "2"
                                    , property "display" "grid"
                                    , property "place-items" "center"
                                    ]
                                ]
                                [ TrackerChart.view { season = eventSummary.season, eventName = eventSummary.name } analysis standings ]
                            , div
                                [ Attributes.class "card bg-base-200 overflow-hidden"
                                , css
                                    [ property "grid-row" "2"
                                    , property "grid-column" "2"
                                    ]
                                ]
                                [ div [ Attributes.class "card-body p-3" ]
                                    [ Html.map CompareWidgetMsg <|
                                        CompareWidget.viewCharts { width = 870, height = 200 } compareProps m.compare
                                    ]
                                ]
                            , div
                                [ Attributes.class "card bg-base-200"
                                , css
                                    [ property "grid-row" "1 / 3"
                                    , property "grid-column" "3"
                                    ]
                                ]
                                []
                            , div
                                [ css
                                    [ property "grid-row" "3"
                                    , property "grid-column" "1 / -1"
                                    ]
                                ]
                                [ Html.map CompareWidgetMsg <|
                                    CompareWidget.viewCarSelector compareProps m.compare
                                ]
                            ]

                    Events ->
                        eventsView m.eventsState raceControl
                ]
            ]
        }


navigation : EventSummary -> RaceControl.Model -> Mode -> Html Msg
navigation eventSummary raceControl currentMode =
    let
        headerTitle =
            eventSummary.name ++ " (" ++ String.fromInt eventSummary.season ++ ")"
    in
    nav
        [ Attributes.class "p-3"
        , css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr auto"
            , alignItems center
            , property "column-gap" "40px"
            ]
        ]
        [ div [ Attributes.class "text-sm whitespace-nowrap" ] [ text headerTitle ]
        , viewPlayerControls raceControl
        , viewModeSelector currentMode
        ]


viewModeSelector : Mode -> Html Msg
viewModeSelector currentMode =
    div [ Attributes.class "join" ]
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
            ("join-item btn btn-sm btn-soft"
                ++ (if isActive then
                        " btn-active"

                    else
                        ""
                   )
            )
        ]
        [ text label ]


viewPlayerControls : RaceControl.Model -> Html Msg
viewPlayerControls raceControl =
    div [ Attributes.class "flex items-center gap-8" ]
        [ div [ Attributes.class "flex items-center gap-2" ]
            [ viewPlayPauseButton raceControl
            , viewSkipControls
            ]
        , viewProgressBar raceControl
        , viewSpeedControls raceControl.clock.playbackSpeed
        ]


viewPlayPauseButton : RaceControl.Model -> Html Msg
viewPlayPauseButton raceControl =
    let
        ( icon, action, isDisabled ) =
            case raceControl.clock.state of
                Initial ->
                    ( "▶", StartRace, False )

                Started _ _ ->
                    ( "■", PauseRace, False )

                Paused _ ->
                    ( "▶", StartRace, False )

                Finished ->
                    ( "■", PauseRace, True )
    in
    button
        [ onClick action
        , Attributes.disabled isDisabled
        , Attributes.class "btn btn-circle btn-sm btn-ghost text-xs"
        ]
        [ text icon ]


viewSpeedControls : Clock.PlaybackSpeed -> Html Msg
viewSpeedControls currentSpeed =
    div [ Attributes.class "join" ]
        [ speedSegmentButton "1×" Clock.Speed1x (currentSpeed == Clock.Speed1x)
        , speedSegmentButton "10×" Clock.Speed10x (currentSpeed == Clock.Speed10x)
        , speedSegmentButton "60×" Clock.Speed60x (currentSpeed == Clock.Speed60x)
        ]


speedSegmentButton : String -> Clock.PlaybackSpeed -> Bool -> Html Msg
speedSegmentButton label speed isActive =
    joinButton label isActive (RaceControlMsg (RaceControl.SetPlaybackSpeed speed))


viewSkipControls : Html Msg
viewSkipControls =
    div [ Attributes.class "join" ]
        [ joinButton "+10s" False (RaceControlMsg (RaceControl.SkipTime (10 * 1000)))
        , joinButton "+1m" False (RaceControlMsg (RaceControl.SkipTime (60 * 1000)))
        , joinButton "+1h" False (RaceControlMsg (RaceControl.SkipTime (60 * 60 * 1000)))
        ]


viewProgressBar : RaceControl.Model -> Html Msg
viewProgressBar { clock, lapTotal, lapCount, timeLimit } =
    let
        elapsed =
            Clock.getElapsed clock

        remaining =
            timeLimit - elapsed
    in
    div [ Attributes.class "flex flex-col gap-2 flex-1 min-w-0 text-xs font-medium tabular-nums opacity-70" ]
        [ div [ Attributes.class "flex justify-between" ]
            [ div [] [ text (Clock.toString clock) ]
            , div [] [ text ("Lap " ++ String.fromInt lapCount ++ " / " ++ String.fromInt lapTotal) ]
            , div [] [ text (Duration.toString remaining |> dropRight 4) ]
            ]
        , input
            [ type_ "range"
            , Attributes.min "0"
            , Attributes.max (String.fromInt lapTotal)
            , value (String.fromInt lapCount)
            , onInput (String.toInt >> Maybe.withDefault 0 >> RaceControl.SetCount >> RaceControlMsg)
            , Attributes.class "range range-xs w-full"
            ]
            []
        ]


eventsView : DataView.Model -> RaceControl.Model -> Html Msg
eventsView eventsState raceControl =
    let
        currentElapsed =
            Clock.getElapsed raceControl.clock

        occurredEvents =
            raceControl.timelineEvents
                |> List.filter (\event -> currentElapsed >= event.eventTime)
                |> List.sortBy .eventTime
    in
    div []
        [ Html.h2 [] [ text "Race Events" ]
        , DataView.view eventsConfig eventsState occurredEvents
        ]


eventsConfig : DataView.Config TimelineEvent Msg
eventsConfig =
    { toId = .eventTime >> Duration.toString
    , toMsg = EventsMsg
    , columns =
        [ DataView.customColumn
            { label = "Time"
            , getter = .eventTime >> Duration.toString
            , sorter = compareBy .eventTime
            }
        , DataView.stringColumn
            { label = "Car"
            , getter =
                \event ->
                    case event.eventType of
                        CarEvent carNumber _ ->
                            carNumber

                        _ ->
                            ""
            }
        , DataView.stringColumn
            { label = "Event"
            , getter = .eventType >> eventTypeToString
            }
        ]
    }


eventTypeToString : EventType -> String
eventTypeToString eventType =
    case eventType of
        RaceStart ->
            "Race Started"

        CarEvent _ (Start _) ->
            "Start"

        CarEvent _ (LapCompleted lap _) ->
            "Lap " ++ String.fromInt lap ++ " Completed"

        CarEvent _ (PitIn _) ->
            "Pit In"

        CarEvent _ (PitOut _) ->
            "Pit Out"

        CarEvent _ Retirement ->
            "Retirement"

        CarEvent _ Checkered ->
            "Checkered Flag"
