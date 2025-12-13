module Route.Wec.Season_.Event_ exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import Browser.Events
import Css exposing (..)
import Css.Transitions as Transitions exposing (transition)
import Data.Series.EventSummary exposing (EventSummary)
import DataView
import DataView.Options exposing (PaginationOption(..), SelectingOption(..))
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html.Styled as Html exposing (Html, button, div, input, main_, nav, text)
import Html.Styled.Attributes as Attributes exposing (attribute, css, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Html.Styled.Lazy as Lazy
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock as Clock exposing (State(..))
import Motorsport.Duration as Duration
import Motorsport.Leaderboard as Leaderboard exposing (initialSort)
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel as ViewModel
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
                [ attribute "data-theme" "dark"
                , css
                    [ height (pct 100)
                    , property "display" "grid"
                    , property "grid-template-rows" "auto 1fr"
                    ]
                ]
                [ navigation eventSummary raceControl m.mode
                , let
                    viewModel =
                        ViewModel.init raceControl

                    compareProps =
                        { eventSummary = eventSummary
                        , viewModel = viewModel
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
                                , padding (px 10)
                                , property "display" "grid"
                                , property "grid-template-columns" "350px 1fr 350px"
                                , property "grid-template-rows" "1fr 135px"
                                , property "row-gap" "10px"
                                ]
                            ]
                            [ div
                                [ css
                                    [ property "grid-row" "1"
                                    , property "grid-column" "1"
                                    , property "height" "100%"
                                    ]
                                ]
                                [ LiveStandingsWidget.view
                                    { eventSummary = eventSummary
                                    , viewModel = viewModel
                                    , onSelectCar = (\item -> CompareWidget.ToggleCar item.metadata.carNumber) >> CompareWidgetMsg
                                    }
                                ]
                            , div
                                [ css
                                    [ property "grid-row" "1"
                                    , property "grid-column" "2"
                                    , property "display" "grid"
                                    , property "place-items" "center"
                                    ]
                                ]
                                [ TrackerChart.view { season = eventSummary.season, eventName = eventSummary.name } analysis viewModel ]
                            , div
                                [ css
                                    [ property "grid-row" "1"
                                    , property "grid-column" "3"
                                    , overflowY scroll
                                    ]
                                ]
                                [ Html.map CompareWidgetMsg <|
                                    Lazy.lazy2 CompareWidget.viewCharts compareProps m.compare
                                ]
                            , div
                                [ css
                                    [ property "grid-row" "2"
                                    , property "grid-column" "1 / -1"
                                    ]
                                ]
                                [ Html.map CompareWidgetMsg <|
                                    Lazy.lazy2 CompareWidget.viewCarSelector compareProps m.compare
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
    nav [ css [ padding (px 12) ] ]
        [ div
            [ css
                [ property "display" "grid"
                , property "grid-template-columns" "auto 1fr auto"
                , alignItems center
                , property "column-gap" "80px"
                ]
            ]
            [ div
                [ css
                    [ fontSize (px 14)
                    , color (hex "ffffff")
                    ]
                ]
                [ text headerTitle ]
            , viewPlayerControls raceControl
            , viewModeSelector currentMode
            ]
        ]



-- SEGMENT CONTROL STYLES


segmentControlContainer : List (Html msg) -> Html msg
segmentControlContainer children =
    div
        [ css
            [ property "display" "grid"
            , property "grid-auto-flow" "column"
            , property "column-gap" "2px"
            , backgroundColor (rgba 255 255 255 0.06)
            , borderRadius (px 16)
            , padding (px 3)
            , border3 (px 1) solid (rgba 255 255 255 0.08)
            ]
        ]
        children


segmentButton : Bool -> List Style
segmentButton isActive =
    [ borderRadius (px 13)
    , border zero
    , backgroundColor
        (if isActive then
            rgba 255 255 255 0.12

         else
            rgba 255 255 255 0
        )
    , color
        (if isActive then
            hex "ffffff"

         else
            rgba 255 255 255 0.6
        )
    , fontWeight
        (if isActive then
            int 600

         else
            int 500
        )
    , cursor pointer
    , transition
        [ Transitions.backgroundColor3 200 0 Transitions.ease
        , Transitions.color3 200 0 Transitions.ease
        , Transitions.transform 100
        ]
    , hover
        [ backgroundColor
            (if isActive then
                rgba 255 255 255 0.12

             else
                rgba 255 255 255 0.06
            )
        , color (hex "ffffff")
        ]
    , active
        [ transform (scale 0.97)
        ]
    , property "display" "grid"
    , property "place-items" "center"
    , padding2 (px 4) (px 16)
    , fontSize (px 12)
    , fontVariantNumeric tabularNums
    ]


viewModeSelector : Mode -> Html Msg
viewModeSelector currentMode =
    segmentControlContainer
        [ modeButton "Tracker" Tracker (currentMode == Tracker)
        , modeButton "Events" Events (currentMode == Events)
        ]


modeButton : String -> Mode -> Bool -> Html Msg
modeButton label mode isActive =
    button
        [ onClick (ModeChange mode)
        , css (segmentButton isActive)
        ]
        [ text label ]


viewPlayerControls : RaceControl.Model -> Html Msg
viewPlayerControls raceControl =
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto 1fr auto"
            , alignItems center
            , property "column-gap" "32px"
            ]
        ]
        [ viewControlButtons raceControl
        , viewProgressBar raceControl
        , viewSpeedControls raceControl.clock.playbackSpeed
        ]


viewControlButtons : RaceControl.Model -> Html Msg
viewControlButtons raceControl =
    div
        [ css
            [ property "display" "grid"
            , property "grid-auto-flow" "column"
            , alignItems center
            , property "column-gap" "8px"
            ]
        ]
        [ viewPlayPauseButton raceControl
        , viewSkipControls
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
        , css
            [ width (px 32)
            , height (px 32)
            , borderRadius (pct 50)
            , border3 (px 1) solid (rgba 255 255 255 0.15)
            , backgroundColor (rgba 255 255 255 0.08)
            , color (rgba 255 255 255 0.9)
            , fontSize (px 12)
            , cursor
                (if isDisabled then
                    default

                 else
                    pointer
                )
            , property "display" "grid"
            , property "place-items" "center"
            , transition
                [ Transitions.backgroundColor3 200 0 Transitions.ease
                , Transitions.color3 200 0 Transitions.ease
                , Transitions.transform 100
                ]
            , hover
                (if not isDisabled then
                    [ transform (scale 1.08)
                    , backgroundColor (rgba 255 255 255 0.15)
                    , color (hex "ffffff")
                    ]

                 else
                    []
                )
            , active
                [ transform (scale 0.95) ]
            , opacity
                (if isDisabled then
                    num 0.5

                 else
                    num 1
                )
            ]
        ]
        [ text icon ]


speedIconButton : String -> Clock.PlaybackSpeed -> Bool -> Html Msg
speedIconButton label speed isActive =
    button
        [ onClick (RaceControlMsg (RaceControl.SetPlaybackSpeed speed))
        , css
            [ width (px 40)
            , height (px 40)
            , borderRadius (pct 50)
            , padding zero
            , border3 (px 1)
                solid
                (if isActive then
                    rgba 255 255 255 0.3

                 else
                    rgba 255 255 255 0.1
                )
            , backgroundColor
                (if isActive then
                    rgba 255 255 255 0.15

                 else
                    rgba 255 255 255 0
                )
            , color
                (if isActive then
                    hex "ffffff"

                 else
                    rgba 255 255 255 0.6
                )
            , fontSize (px 13)
            , fontWeight (int 700)
            , fontVariantNumeric tabularNums
            , property "display" "grid"
            , property "place-items" "center"
            , cursor pointer
            , transition
                [ Transitions.backgroundColor 150
                , Transitions.borderColor 150
                , Transitions.color 150
                , Transitions.transform 100
                ]
            , hover
                [ backgroundColor
                    (if isActive then
                        rgba 255 255 255 0.2

                     else
                        rgba 255 255 255 0.08
                    )
                , borderColor (rgba 255 255 255 0.4)
                , color (hex "ffffff")
                , transform (scale 1.05)
                ]
            , active
                [ transform (scale 0.95) ]
            ]
        ]
        [ text label ]


viewSpeedControls : Clock.PlaybackSpeed -> Html Msg
viewSpeedControls currentSpeed =
    segmentControlContainer
        [ speedSegmentButton "1×" Clock.Speed1x (currentSpeed == Clock.Speed1x)
        , speedSegmentButton "10×" Clock.Speed10x (currentSpeed == Clock.Speed10x)
        , speedSegmentButton "60×" Clock.Speed60x (currentSpeed == Clock.Speed60x)
        ]


speedSegmentButton : String -> Clock.PlaybackSpeed -> Bool -> Html Msg
speedSegmentButton label speed isActive =
    button
        [ onClick (RaceControlMsg (RaceControl.SetPlaybackSpeed speed))
        , css (segmentButton isActive)
        ]
        [ text label ]


viewSkipControls : Html Msg
viewSkipControls =
    segmentControlContainer
        [ skipButton "+10s" (RaceControl.SkipTime (10 * 1000))
        , skipButton "+1m" (RaceControl.SkipTime (60 * 1000))
        , skipButton "+1h" (RaceControl.SkipTime (60 * 60 * 1000))
        ]


skipButton : String -> RaceControl.Msg -> Html Msg
skipButton label msg =
    button
        [ onClick (RaceControlMsg msg)
        , css (segmentButton False)
        ]
        [ text label ]


viewProgressBar : RaceControl.Model -> Html Msg
viewProgressBar { clock, lapTotal, lapCount, timeLimit } =
    let
        elapsed =
            Clock.getElapsed clock

        remaining =
            timeLimit - elapsed

        progress =
            toFloat lapCount / toFloat lapTotal * 100
    in
    div
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "auto auto auto"
            , justifyContent spaceBetween
            , property "grid-template-rows" "auto auto"
            , property "gap" "8px"
            , fontSize (px 12)
            , color (rgba 255 255 255 0.7)
            , fontWeight (int 500)
            , fontVariantNumeric tabularNums
            ]
        ]
        [ div [] [ text (Clock.toString clock) ]
        , div [ css [] ] [ text ("Lap " ++ String.fromInt lapCount ++ " / " ++ String.fromInt lapTotal) ]
        , div [] [ text (Duration.toString remaining |> dropRight 4) ]
        , div
            [ css
                [ property "grid-column" "1 / -1"
                , property "display" "grid"
                , property "grid-template-rows" "8px"
                , backgroundColor (rgba 255 255 255 0.08)
                , borderRadius (px 4)
                , cursor pointer
                , overflow hidden
                , border3 (px 1) solid (rgba 255 255 255 0.06)
                ]
            ]
            [ div
                [ css
                    [ property "grid-area" "1 / -1"
                    , width (pct progress)
                    , backgroundColor (hex "ffffff")
                    , borderRadius (px 4)
                    , transition [ Transitions.width3 150 0 Transitions.ease ]
                    ]
                ]
                []
            , input
                [ type_ "range"
                , Attributes.min "0"
                , Attributes.max (String.fromInt lapTotal)
                , value (String.fromInt lapCount)
                , onInput (String.toInt >> Maybe.withDefault 0 >> RaceControl.SetCount >> RaceControlMsg)
                , css
                    [ property "grid-area" "1 / -1"
                    , opacity zero
                    , cursor pointer
                    ]
                ]
                []
            ]
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
