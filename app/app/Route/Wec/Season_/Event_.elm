module Route.Wec.Season_.Event_ exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import Browser.Events
import Css exposing (alignItems, backgroundColor, center, displayFlex, em, fontSize, height, hidden, hsl, justifyContent, overflowY, padding, pct, position, property, px, right, scroll, spaceBetween, sticky, textAlign, top, width, zero)
import Data.Series as Series
import DataView
import DataView.Options exposing (PaginationOption(..), SelectingOption(..))
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html.Styled as Html exposing (Html, div, h1, img, input, main_, nav, text)
import Html.Styled.Attributes as Attributes exposing (css, src, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Html.Styled.Lazy as Lazy
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.PositionHistory as PositionHistoryChart
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock as Clock exposing (Model(..))
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (carNumberColumn_Wec, currentLapColumn_LeMans24h, currentLapColumn_Wec, customColumn, driverAndTeamColumn_Wec, histogramColumn, initialSort, intColumn, lastLapColumn_LeMans24h, lastLapColumn_Wec, performanceColumn, veryCustomColumn)
import Motorsport.RaceControl as RaceControl exposing (CarEventType(..), Event, EventType(..))
import Motorsport.RaceControl.ViewModel as ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Utils exposing (compareBy)
import Motorsport.Widget.BestLapTimes as BestLapTimesWidget
import Motorsport.Widget.CloseBattles as CloseBattlesWidget
import Motorsport.Widget.LapTimeDistribution as LapTimeDistributionWidget
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatefulRoute)
import Shared
import String exposing (dropRight)
import Task
import Time
import UI.Button exposing (button, labeledButton)
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
        ]



-- MODEL


type alias Model =
    { mode : Mode
    , leaderboardState : Leaderboard.Model
    , eventsState : DataView.Model
    , query : String
    }


type Mode
    = Leaderboard
    | PositionHistory
    | Tracker
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



-- SUBSCRIPTIONS


subscriptions : RouteParams -> UrlPath -> Shared.Model -> Model -> Sub Msg
subscriptions routeParams path shared model =
    case shared.raceControl.clock of
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
view app ({ eventSummary, analysis, raceControl } as shared) { mode, leaderboardState, eventsState } =
    View.map PagesMsg.fromMsg
        { title = "Wec"
        , body =
            [ main_
                [ css
                    [ height (pct 100)
                    , property "display" "grid"
                    , property "grid-template-rows" "auto 1fr"
                    ]
                ]
                [ header shared
                , let
                    viewModel =
                        ViewModel.init raceControl
                  in
                  case mode of
                    Leaderboard ->
                        case ( eventSummary.season, eventSummary.name ) of
                            ( 2025, "24 Hours of Le Mans" ) ->
                                Leaderboard.view (config_LeMans24h eventSummary.season analysis) leaderboardState viewModel

                            _ ->
                                Leaderboard.view (config eventSummary.season analysis) leaderboardState viewModel

                    PositionHistory ->
                        PositionHistoryChart.view raceControl

                    Tracker ->
                        div
                            [ css
                                [ height (pct 100)
                                , overflowY hidden
                                , property "display" "grid"
                                , property "grid-template-columns" "1fr 1fr 350px"
                                , property "grid-gap" "10px"
                                ]
                            ]
                            [ div [ css [ height (pct 100), overflowY scroll ] ]
                                [ case ( eventSummary.season, eventSummary.name ) of
                                    ( 2025, "24 Hours of Le Mans" ) ->
                                        Leaderboard.view (config_LeMans24h eventSummary.season analysis) leaderboardState viewModel

                                    _ ->
                                        Leaderboard.view (config eventSummary.season analysis) leaderboardState viewModel
                                ]
                            , div [ css [ property "display" "grid", property "place-items" "center" ] ]
                                [ case ( eventSummary.season, eventSummary.name ) of
                                    ( 2025, "24 Hours of Le Mans" ) ->
                                        TrackerChart.viewWithMiniSectors analysis viewModel

                                    _ ->
                                        TrackerChart.view analysis viewModel
                                ]
                            , div
                                [ css
                                    [ height (pct 100)
                                    , overflowY hidden
                                    , backgroundColor (hsl 0 0 0.15)
                                    , padding (px 10)
                                    , property "display" "flex"
                                    , property "flex-direction" "column"
                                    , property "gap" "24px"
                                    ]
                                ]
                                [ analysisWidgets analysis viewModel ]
                            ]

                    Events ->
                        eventsView eventsState raceControl
                ]
            ]
        }


header : Shared.Model -> Html Msg
header { eventSummary, raceControl } =
    Html.header
        [ css
            [ position sticky
            , top zero
            , padding (px 10)
            , backgroundColor (hsl 0 0 0.4)
            ]
        ]
        [ h1 [ css [ fontSize (em 1) ] ] [ text eventSummary.name ]
        , div [ css [ displayFlex, justifyContent spaceBetween ] ]
            [ nav []
                [ case raceControl.clock of
                    Initial ->
                        button [ onClick StartRace ] [ text "Start" ]

                    Started _ _ ->
                        button [ onClick PauseRace ] [ text "Pause" ]

                    Paused _ ->
                        button [ onClick StartRace ] [ text "Resume" ]

                    _ ->
                        text ""
                , case raceControl.clock of
                    Started _ _ ->
                        text ""

                    _ ->
                        labeledButton []
                            [ button [ onClick (RaceControlMsg RaceControl.Add10seconds) ] [ text "+10s" ]
                            , button [ onClick (RaceControlMsg RaceControl.NextLap) ] [ text "+1 Lap" ]
                            ]
                ]
            , statusBar raceControl
            , nav []
                [ button [ onClick (ModeChange Leaderboard) ] [ text "Leaderboard" ]
                , button [ onClick (ModeChange PositionHistory) ] [ text "Position History" ]
                , button [ onClick (ModeChange Tracker) ] [ text "Tracker" ]
                , button [ onClick (ModeChange Events) ] [ text "Events" ]
                ]
            ]
        ]


statusBar : RaceControl.Model -> Html.Html Msg
statusBar { clock, lapTotal, lapCount, timeLimit } =
    let
        elapsed =
            Clock.getElapsed clock

        remaining =
            timeLimit - elapsed
    in
    div [ css [ displayFlex, alignItems center, property "column-gap" "10px" ] ]
        [ div []
            [ div [] [ text "Elapsed" ]
            , div [] [ text (Clock.toString clock) ]
            ]
        , input
            [ type_ "range"
            , Attributes.max <| String.fromInt lapTotal
            , value (String.fromInt lapCount)
            , onInput (String.toInt >> Maybe.withDefault 0 >> RaceControl.SetCount >> RaceControlMsg)
            ]
            []
        , div [ css [ textAlign right ] ]
            [ div [] [ text "Remaining" ]
            , div [] [ text (Duration.toString remaining |> dropRight 4) ]
            ]
        ]


analysisWidgets : Analysis -> ViewModel -> Html Msg
analysisWidgets analysis viewModel =
    div
        [ css
            [ height (pct 100)
            , property "display" "grid"
            , property "grid-template-rows" "auto auto 1fr"
            , property "row-gap" "10px"
            ]
        ]
        [ BestLapTimesWidget.view analysis viewModel
        , LapTimeDistributionWidget.view analysis viewModel
        , CloseBattlesWidget.view viewModel
        ]


config : Int -> Analysis -> Leaderboard.Config ViewModelItem Msg
config season analysis =
    { toId = .metaData >> .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ intColumn { label = "", getter = .position }
        , carNumberColumn_Wec season { getter = .metaData }
        , driverAndTeamColumn_Wec { getter = .metaData }
        , let
            view_ carNumber =
                case Series.carImageUrl_Wec season carNumber of
                    Just url ->
                        img [ src url, css [ width (px 100) ] ] []

                    Nothing ->
                        text ""
          in
          veryCustomColumn
            { label = "-"
            , getter = .metaData >> .carNumber >> Lazy.lazy view_
            , sorter = compareBy (.metaData >> .carNumber)
            }
        , intColumn { label = "Lap", getter = .lap }
        , customColumn
            { label = "Gap"
            , getter = .timing >> .gap >> Gap.toString
            , sorter = compareBy .position
            }
        , customColumn
            { label = "Interval"
            , getter = .timing >> .interval >> Gap.toString
            , sorter = compareBy .position
            }
        , currentLapColumn_Wec
            { getter = identity
            , sorter = compareBy (.currentLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , lastLapColumn_Wec
            { getter = .lastLap
            , sorter = compareBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , performanceColumn
            { getter = .history
            , sorter = compareBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , histogramColumn
            { getter = .history
            , sorter = compareBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            , coefficient = 1.2
            }
        ]
    }


eventsView : DataView.Model -> RaceControl.Model -> Html Msg
eventsView eventsState raceControl =
    let
        currentElapsed =
            Clock.getElapsed raceControl.clock

        occurredEvents =
            raceControl.events
                |> List.filter (\event -> currentElapsed >= event.eventTime)
                |> List.sortBy .eventTime
    in
    div []
        [ Html.h2 [] [ text "Race Events" ]
        , DataView.view eventsConfig eventsState occurredEvents
        ]


eventsConfig : DataView.Config Event Msg
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

        CarEvent _ Retirement ->
            "Retirement"

        CarEvent _ Checkered ->
            "Checkered Flag"

        CarEvent _ (LapCompleted lap) ->
            "Lap " ++ String.fromInt lap ++ " Completed"


config_LeMans24h : Int -> Analysis -> Leaderboard.Config ViewModelItem Msg
config_LeMans24h season analysis =
    { toId = .metaData >> .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ intColumn { label = "", getter = .position }
        , carNumberColumn_Wec season { getter = .metaData }
        , driverAndTeamColumn_Wec { getter = .metaData }
        , let
            view_ carNumber =
                case Series.carImageUrl_Wec season carNumber of
                    Just url ->
                        img [ src url, css [ width (px 100) ] ] []

                    Nothing ->
                        text ""
          in
          veryCustomColumn
            { label = "-"
            , getter = .metaData >> .carNumber >> Lazy.lazy view_
            , sorter = compareBy (.metaData >> .carNumber)
            }
        , intColumn { label = "Lap", getter = .lap }
        , customColumn
            { label = "Gap"
            , getter = .timing >> .gap >> Gap.toString
            , sorter = compareBy .position
            }
        , customColumn
            { label = "Interval"
            , getter = .timing >> .interval >> Gap.toString
            , sorter = compareBy .position
            }
        , currentLapColumn_LeMans24h
            { getter = identity
            , sorter = compareBy (.currentLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , lastLapColumn_LeMans24h
            { getter = .lastLap
            , sorter = compareBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , performanceColumn
            { getter = .history
            , sorter = compareBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , histogramColumn
            { getter = .history
            , sorter = compareBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            , coefficient = 1.2
            }
        ]
    }
