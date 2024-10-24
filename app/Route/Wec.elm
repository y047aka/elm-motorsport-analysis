module Route.Wec exposing (ActionData, Data, Model, Msg(..), RouteParams, data, route)

import BackendTask exposing (BackendTask)
import Css exposing (alignItems, backgroundColor, center, displayFlex, hsl, justifyContent, position, property, right, spaceBetween, sticky, textAlign, top, zero)
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html.Styled as Html exposing (div, header, input, nav, text)
import Html.Styled.Attributes as Attributes exposing (css, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.PositionHistory as PositionHistoryChart
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (LeaderboardItem, bestTimeColumn, carNumberColumn_Wec, customColumn, driverAndTeamColumn_Wec, histogramColumn, initialSort, intColumn, lastLapColumn, performanceColumn, sectorTimeColumn)
import Motorsport.RaceControl as RaceControl exposing (State(..))
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App)
import Shared
import String exposing (dropRight)
import Task
import Time
import UI.Button exposing (button, labeledButton)
import UrlPath exposing (UrlPath)
import View exposing (View)


type alias RouteParams =
    {}


route =
    RouteBuilder.single { data = data, head = \_ -> [] }
        |> RouteBuilder.buildWithSharedState
            { init = init
            , update = update
            , view = view
            , subscriptions = subscriptions
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
    , Effect.none
    )



-- UPDATE


type Msg
    = StartRace
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
        StartRace ->
            ( m, Task.perform (RaceControl.Start >> RaceControlMsg) Time.now |> Effect.fromCmd, Nothing )

        ModeChange mode ->
            ( { m | mode = mode }, Effect.none, Nothing )

        RaceControlMsg raceControlMsg ->
            ( m, Effect.none, Just (Shared.RaceControlMsg_Wec raceControlMsg) )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            , Nothing
            )



-- SUBSCRIPTIONS


subscriptions : {} -> UrlPath -> Shared.Model -> Model -> Sub Msg
subscriptions _ _ shared model =
    case shared.raceControl_Wec.state of
        Started _ _ ->
            Time.every 100 (RaceControl.Tick >> RaceControlMsg)

        _ ->
            Sub.none



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
    App Data ActionData {}
    -> Shared.Model
    -> Model
    -> View (PagesMsg Msg)
view app { analysis_Wec, raceControl_Wec } { mode, leaderboardState } =
    View.map PagesMsg.fromMsg
        { title = "Wec"
        , body =
            [ header
                [ css
                    [ position sticky
                    , top zero
                    , displayFlex
                    , justifyContent spaceBetween
                    , backgroundColor (hsl 0 0 0.4)
                    ]
                ]
                [ nav []
                    [ case raceControl_Wec.state of
                        Initial ->
                            button [ onClick StartRace ] [ text "Start" ]

                        Started _ _ ->
                            button [ onClick (RaceControlMsg RaceControl.Pause) ] [ text "Pause" ]

                        Paused ->
                            button [ onClick StartRace ] [ text "Resume" ]

                        _ ->
                            text ""
                    , case raceControl_Wec.state of
                        Started _ _ ->
                            text ""

                        _ ->
                            labeledButton []
                                [ button [ onClick (RaceControlMsg RaceControl.Add10seconds) ] [ text "+10s" ]
                                , button [ onClick (RaceControlMsg RaceControl.NextLap) ] [ text "+1 Lap" ]
                                ]
                    ]
                , statusBar raceControl_Wec
                , nav []
                    [ button [ onClick (ModeChange Leaderboard) ] [ text "Leaderboard" ]
                    , button [ onClick (ModeChange PositionHistory) ] [ text "Position History" ]
                    ]
                ]
            , case mode of
                Leaderboard ->
                    Leaderboard.view (config analysis_Wec) leaderboardState raceControl_Wec

                PositionHistory ->
                    PositionHistoryChart.view raceControl_Wec
            ]
        }


statusBar : RaceControl.Model -> Html.Html Msg
statusBar { raceClock, lapTotal } =
    div [ css [ displayFlex, alignItems center, property "column-gap" "10px" ] ]
        [ div []
            [ div [] [ text "Elapsed" ]
            , div [] [ text (raceClock.elapsed |> Duration.toString |> dropRight 4) ]
            ]
        , input
            [ type_ "range"
            , Attributes.max <| String.fromInt lapTotal
            , value (String.fromInt raceClock.lapCount)
            , onInput (String.toInt >> Maybe.withDefault 0 >> RaceControl.SetCount >> RaceControlMsg)
            ]
            []
        , div [ css [ textAlign right ] ]
            [ div [] [ text "Remaining" ]
            , div [] [ text ((6 * 60 * 60 * 1000 - raceClock.elapsed) |> Duration.toString |> dropRight 4) ]
            ]
        ]


config : Analysis -> Leaderboard.Config LeaderboardItem Msg
config analysis =
    { toId = .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ intColumn { label = "", getter = .position }
        , carNumberColumn_Wec { carNumber = .carNumber, class = .class }
        , driverAndTeamColumn_Wec
        , intColumn { label = "Lap", getter = .lap }
        , customColumn
            { label = "Gap"
            , getter = .gap >> Gap.toString
            , sorter = List.sortBy .position
            }
        , customColumn
            { label = "Interval"
            , getter = .interval >> Gap.toString
            , sorter = List.sortBy .position
            }
        , sectorTimeColumn
            { label = "S1"
            , getter = \{ sector_1, s1_best } -> { time = sector_1, best = s1_best }
            , fastestSectorTime = analysis.sector_1_fastest
            }
        , sectorTimeColumn
            { label = "S2"
            , getter = \{ sector_2, s2_best } -> { time = sector_2, best = s2_best }
            , fastestSectorTime = analysis.sector_2_fastest
            }
        , sectorTimeColumn
            { label = "S3"
            , getter = \{ sector_3, s3_best } -> { time = sector_3, best = s3_best }
            , fastestSectorTime = analysis.sector_3_fastest
            }
        , lastLapColumn
            { getter = identity
            , sorter = List.sortBy .lastLapTime
            , analysis = analysis
            }
        , bestTimeColumn { getter = .best }
        , performanceColumn
            { getter = .history
            , sorter = List.sortBy .lastLapTime
            , analysis = analysis
            }
        , histogramColumn
            { getter = .history
            , sorter = List.sortBy .lastLapTime
            , analysis = analysis
            , coefficient = 1.2
            }
        ]
    }
