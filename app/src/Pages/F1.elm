module Pages.F1 exposing (Model, Msg, page)

import Css exposing (displayFlex, justifyContent, spaceBetween)
import Effect exposing (Effect)
import Html.Styled exposing (header, input, nav, text)
import Html.Styled.Attributes as Attributes exposing (css, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.PositionHistory as PositionHistoryChart
import Motorsport.Clock as Clock
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (bestTimeColumn, customColumn, driverNameColumn_F1, histogramColumn, initialSort, intColumn, lastLapColumn_F1, performanceColumn, stringColumn)
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel exposing (ViewModelItem)
import Page exposing (Page)
import Route exposing (Route)
import Shared
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , view = view shared
        , subscriptions = \_ -> Sub.none
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


init : () -> ( Model, Effect Msg )
init () =
    ( { mode = Leaderboard
      , leaderboardState = initialSort "Position"
      , query = ""
      }
    , Effect.fetchJson "/static/lapTimes.json"
    )



-- UPDATE


type Msg
    = ModeChange Mode
    | RaceControlMsg RaceControl.Msg
    | LeaderboardMsg Leaderboard.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    case msg of
        ModeChange mode ->
            ( { m | mode = mode }, Effect.none )

        RaceControlMsg raceControlMsg ->
            ( m, Effect.updateRaceControl_F1 raceControlMsg )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            )



-- VIEW


view : Shared.Model -> Model -> View Msg
view { analysis_F1, raceControl_F1 } { mode, leaderboardState } =
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
                    [ button [ onClick (RaceControlMsg RaceControl.PreviousLap) ] [ text "-" ]
                    , basicLabel [] [ text (String.fromInt lapCount) ]
                    , button [ onClick (RaceControlMsg RaceControl.NextLap) ] [ text "+" ]
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
                Leaderboard.view (config analysis_F1) leaderboardState raceControl_F1

            PositionHistory ->
                PositionHistoryChart.view raceControl_F1
        ]
    }


config : Analysis -> Leaderboard.Config ViewModelItem Msg
config analysis =
    { toId = .metaData >> .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ intColumn { label = "", getter = .position }
        , stringColumn { label = "#", getter = .metaData >> .carNumber }
        , driverNameColumn_F1
            { label = "Driver"
            , getter = .metaData >> .drivers >> Driver.findCurrentDriver >> Maybe.map .name >> Maybe.withDefault ""
            }
        , stringColumn { label = "Team", getter = .metaData >> .team }
        , intColumn { label = "Lap", getter = .lap }
        , customColumn
            { label = "Gap"
            , getter = .timing >> .gap >> Gap.toString
            , sorter = List.sortBy .position
            }
        , lastLapColumn_F1
            { getter = .lastLap
            , sorter = List.sortBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , bestTimeColumn { getter = .lastLap >> Maybe.map .best }
        , performanceColumn
            { getter = .history
            , sorter = List.sortBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , histogramColumn
            { getter = .history
            , sorter = List.sortBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            , coefficient = 1.2
            }
        ]
    }
