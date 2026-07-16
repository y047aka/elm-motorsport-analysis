module Route.F1 exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import Css exposing (displayFlex, justifyContent, spaceBetween)
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html.Styled exposing (header, input, nav, text)
import Html.Styled.Attributes as Attributes exposing (class, css, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Chart.PositionHistory as PositionHistoryChart
import Motorsport.Clock as Clock
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (bestTimeColumn, customColumn, driverNameColumn_F1, histogramColumn, initialSort, intColumn, lastLapColumn_F1, performanceColumn, stringColumn)
import Motorsport.RaceControl as RaceControl
import Motorsport.ViewModel.LapHistory as LapHistory exposing (LapHistory)
import Motorsport.ViewModel.Reference exposing (Reference)
import Motorsport.ViewModel.Standings exposing (Entry)
import Motorsport.Utils exposing (compareBy)
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatefulRoute)
import Shared
import Task
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)
import View exposing (View)


type alias RouteParams =
    {}


route : StatefulRoute RouteParams Data ActionData Model Msg
route =
    RouteBuilder.single { data = data, head = \_ -> [] }
        |> RouteBuilder.buildWithSharedState
            { init = init
            , update = update
            , view = view
            , subscriptions = \_ _ _ _ -> Sub.none
            }



-- MODEL


type alias Model =
    { mode : Mode
    , leaderboardState : Leaderboard.Model
    , query : String
    }


type Mode
    = Leaderboard
    | PositionHistory


init :
    App Data ActionData {}
    -> Shared.Model
    -> ( Model, Effect Msg )
init app shared =
    ( { mode = Leaderboard
      , leaderboardState = initialSort "Position"
      , query = ""
      }
    , Effect.fromCmd
        (Task.succeed (Shared.FetchJson "/static/lapTimes.json")
            |> Task.perform SharedMsg
        )
    )



-- UPDATE


type Msg
    = SharedMsg Shared.Msg
    | ModeChange Mode
    | RaceControlMsg RaceControl.Msg
    | LeaderboardMsg Leaderboard.Msg


update :
    App Data ActionData {}
    -> Shared.Model
    -> Msg
    -> Model
    -> ( Model, Effect Msg, Maybe Shared.Msg )
update app shared msg m =
    case msg of
        SharedMsg sharedMsg ->
            ( m, Effect.none, Just sharedMsg )

        ModeChange mode ->
            ( { m | mode = mode }, Effect.none, Nothing )

        RaceControlMsg raceControlMsg ->
            ( m, Effect.none, Just (Shared.RaceControlMsg_F1 raceControlMsg) )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            , Nothing
            )



-- DATA


type alias Data =
    {}


type alias ActionData =
    {}


data : BackendTask FatalError Data
data =
    BackendTask.succeed {}



-- VIEW


view :
    App Data ActionData RouteParams
    -> Shared.Model
    -> Model
    -> View (PagesMsg Msg)
view app { viewModel_F1, raceControl_F1 } { mode, leaderboardState } =
    View.map PagesMsg.fromMsg
        { title = "Leaderboard"
        , body =
            let
                { clock, lapTotal, lapCount } =
                    raceControl_F1
            in
            [ header [ css [ displayFlex, justifyContent spaceBetween ] ]
                [ nav []
                    [ input
                        [ type_ "range"
                        , Attributes.max <| String.fromInt lapTotal
                        , value (String.fromInt lapCount)
                        , onInput (String.toInt >> Maybe.withDefault 0 >> RaceControl.SetCount >> RaceControlMsg)
                        ]
                        []
                    , labeledButton []
                        [ button [ class "join-item", onClick (RaceControlMsg RaceControl.PreviousLap) ] [ text "-" ]
                        , basicLabel [ class "join-item" ] [ text (String.fromInt lapCount) ]
                        , button [ class "join-item", onClick (RaceControlMsg RaceControl.NextLap) ] [ text "+" ]
                        ]
                    , text (Clock.getElapsed clock |> Duration.toString)
                    ]
                , nav []
                    [ button [ onClick (ModeChange Leaderboard) ] [ text "Leaderboard" ]
                    , button [ onClick (ModeChange PositionHistory) ] [ text "Position History" ]
                    ]
                ]
            , case mode of
                Leaderboard ->
                    Leaderboard.view (config viewModel_F1.reference viewModel_F1.lapHistory) leaderboardState viewModel_F1.standings

                PositionHistory ->
                    PositionHistoryChart.view raceControl_F1
            ]
        }


config : Reference -> LapHistory -> Leaderboard.Config Entry Msg
config reference lapHistory =
    { toId = .metadata >> .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ intColumn { label = "", getter = .position }
        , stringColumn { label = "#", getter = .metadata >> .carNumber }
        , driverNameColumn_F1
            { label = "Driver"
            , getter = .currentDriver >> Maybe.map .name >> Maybe.withDefault ""
            }
        , stringColumn { label = "Team", getter = .metadata >> .team }
        , intColumn { label = "Lap", getter = .lapsCompleted }
        , customColumn
            { label = "Gap"
            , getter = .gapToLeader >> Gap.toString
            , sorter = compareBy .position
            }
        , lastLapColumn_F1
            { getter = identity
            , sorter = compareBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            }
        , bestTimeColumn { getter = .bestLap }
        , performanceColumn
            { getter = \item -> LapHistory.get item.metadata.carNumber lapHistory
            , sorter = compareBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , reference = reference
            }
        , histogramColumn
            { getter = \item -> LapHistory.get item.metadata.carNumber lapHistory
            , sorter = compareBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , reference = reference
            , coefficient = 1.2
            }
        ]
    }
