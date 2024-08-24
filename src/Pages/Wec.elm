module Pages.Wec exposing (Model, Msg, page)

import Chart.PositionHistory as PositionHistoryChart
import Css exposing (displayFlex, justifyContent, spaceBetween)
import Effect exposing (Effect)
import Html.Styled as Html exposing (header, input, nav, text)
import Html.Styled.Attributes as Attributes exposing (css, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Analysis as Analysis
import Motorsport.Clock as Clock
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (LeaderboardItem, customColumn, histogramColumn, initialSort, intColumn, performanceColumn, stringColumn, timeColumn)
import Motorsport.RaceControl as RaceControl
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
    , Effect.fetchCsv "/static/23_Analysis_Race_Hour 24.csv"
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
            ( m, Effect.updateRaceControl raceControlMsg )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            )



-- VIEW


view : Shared.Model -> Model -> View Msg
view { raceControl, ordersByLap } { mode, leaderboardState } =
    { title = "Wec"
    , body =
        let
            { raceClock, lapTotal } =
                raceControl
        in
        [ header [ css [ displayFlex, justifyContent spaceBetween ] ]
            [ nav []
                [ input
                    [ type_ "range"
                    , Attributes.max <| String.fromInt lapTotal
                    , value (String.fromInt raceClock.lapCount)
                    , onInput (String.toInt >> Maybe.withDefault 0 >> RaceControl.SetCount >> RaceControlMsg)
                    ]
                    []
                , labeledButton []
                    [ button [ onClick (RaceControlMsg RaceControl.PreviousLap) ] [ text "-" ]
                    , basicLabel [] [ text (String.fromInt raceClock.lapCount) ]
                    , button [ onClick (RaceControlMsg RaceControl.NextLap) ] [ text "+" ]
                    ]
                , text <| Clock.toString raceClock
                ]
            , nav []
                [ button [ onClick (ModeChange Leaderboard) ] [ text "Leaderboard" ]
                , button [ onClick (ModeChange PositionHistory) ] [ text "Position History" ]
                ]
            ]
        , case mode of
            Leaderboard ->
                Leaderboard.view (config raceControl) leaderboardState raceControl

            PositionHistory ->
                PositionHistoryChart.view { raceControl = raceControl, ordersByLap = ordersByLap }
        ]
    }


config : RaceControl.Model -> Leaderboard.Config LeaderboardItem Msg
config raceControl =
    let
        analysis =
            Analysis.fromRaceControl raceControl
    in
    { toId = .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ intColumn { label = "Position", getter = .position }
        , stringColumn { label = "#", getter = .carNumber }
        , stringColumn { label = "Driver", getter = .driver }
        , intColumn { label = "Lap", getter = .lap }
        , customColumn
            { label = "Gap"
            , getter = .gap >> Gap.toString
            , sorter = List.sortBy .position
            }
        , timeColumn
            { label = "Time"
            , getter = identity
            , sorter = List.sortBy .time
            , analysis = analysis
            }
        , performanceColumn
            { getter = .history
            , sorter = List.sortBy .time
            , analysis = analysis
            }
        , histogramColumn
            { getter = .history
            , sorter = List.sortBy .time
            , analysis = analysis
            , coefficient = 1.2
            }
        ]
    }
