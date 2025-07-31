module Route.FormulaE.Season_.Event_ exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import Browser.Events
import Css exposing (alignItems, backgroundColor, center, displayFlex, em, fontSize, hsl, justifyContent, position, property, px, right, spaceBetween, sticky, textAlign, top, width, zero)
import Data.Series as Series
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html.Styled as Html exposing (Html, div, h1, img, input, nav, text)
import Html.Styled.Attributes as Attributes exposing (css, src, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.PositionHistory as PositionHistoryChart
import Motorsport.Chart.Tracker as TrackerChart
import Motorsport.Clock as Clock exposing (Model(..))
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (bestTimeColumn, carNumberColumn_Wec, currentLapColumn_Wec, customColumn, driverAndTeamColumn_Wec, histogramColumn, initialSort, intColumn, lastLapColumn_Wec, performanceColumn, veryCustomColumn)
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel as ViewModel exposing (ViewModelItem)
import Motorsport.Utils exposing (compareBy)
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
        [ { season = "2025", event = "R08_tokyo" }
        ]



-- MODEL


type alias Model =
    { mode : Mode
    , leaderboardState : Leaderboard.Model
    , query : String
    }


type Mode
    = Leaderboard
    | PositionHistory
    | Tracker


init :
    App Data ActionData RouteParams
    -> Shared.Model
    -> ( Model, Effect Msg )
init app shared =
    ( { mode = Leaderboard
      , leaderboardState = initialSort "Position"
      , query = ""
      }
    , Effect.fromCmd
        (Task.succeed (Shared.FetchJson_FormulaE { season = app.routeParams.season, event = app.routeParams.event })
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
view app ({ eventSummary, analysis, raceControl } as shared) { mode, leaderboardState } =
    View.map PagesMsg.fromMsg
        { title = "Formula E"
        , body =
            [ header shared
            , let
                viewModel =
                    ViewModel.init raceControl
              in
              case mode of
                Leaderboard ->
                    Leaderboard.view (config eventSummary.season analysis) leaderboardState viewModel

                PositionHistory ->
                    PositionHistoryChart.view raceControl

                Tracker ->
                    TrackerChart.view analysis viewModel
            ]
        }


header : Shared.Model -> Html Msg
header { eventSummary, raceControl } =
    Html.header [ css [ position sticky, top zero, backgroundColor (hsl 0 0 0.4) ] ]
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


config : Int -> Analysis -> Leaderboard.Config ViewModelItem Msg
config season analysis =
    { toId = .metadata >> .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ intColumn { label = "", getter = .position }
        , carNumberColumn_Wec season { getter = .metadata }
        , driverAndTeamColumn_Wec { getter = \item -> { metadata = item.metadata, currentDriver = item.currentDriver } }
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
        , bestTimeColumn { getter = .lastLap >> Maybe.map .best }
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
