module Pages.Wec.Season_.Event_ exposing (Model, Msg, page)

import Browser.Events
import Css exposing (alignItems, backgroundColor, center, displayFlex, em, fontSize, hsl, justifyContent, position, property, px, right, spaceBetween, sticky, textAlign, top, width, zero)
import Data.Series as Series
import Effect exposing (Effect)
import Html.Styled as Html exposing (Html, div, h1, img, input, nav, text)
import Html.Styled.Attributes as Attributes exposing (css, src, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.PositionHistory as PositionHistoryChart
import Motorsport.Clock as Clock exposing (Model(..))
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (bestTimeColumn, carNumberColumn_Wec, currentLapColumn_Wec, customColumn, driverAndTeamColumn_Wec, histogramColumn, initialSort, intColumn, lastLapColumn_Wec, performanceColumn, veryCustomColumn)
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel exposing (ViewModelItem)
import Page exposing (Page)
import Route exposing (Route)
import Shared
import String exposing (dropRight)
import Task
import Time
import UI.Button exposing (button, labeledButton)
import View exposing (View)


page : Shared.Model -> Route { season : String, event : String } -> Page Model Msg
page shared route =
    Page.new
        { init = init route.params
        , update = update
        , view = view shared
        , subscriptions = subscriptions shared
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


init : { season : String, event : String } -> () -> ( Model, Effect Msg )
init params () =
    ( { mode = Leaderboard
      , leaderboardState = initialSort "Position"
      , query = ""
      }
    , Effect.fetchCsv params
    )



-- UPDATE


type Msg
    = StartRace
    | PauseRace
    | ModeChange Mode
    | RaceControlMsg RaceControl.Msg
    | LeaderboardMsg Leaderboard.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    case msg of
        StartRace ->
            ( m, Task.perform (RaceControl.Start >> RaceControlMsg) Time.now |> Effect.sendCmd )

        PauseRace ->
            ( m, Task.perform (RaceControl.Pause >> RaceControlMsg) Time.now |> Effect.sendCmd )

        ModeChange mode ->
            ( { m | mode = mode }, Effect.none )

        RaceControlMsg raceControlMsg ->
            ( m, Effect.updateRaceControl_Wec raceControlMsg )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            )



-- SUBSCRIPTIONS


subscriptions : Shared.Model -> Model -> Sub Msg
subscriptions shared model =
    case shared.raceControl_Wec.clock of
        Started _ _ ->
            Browser.Events.onAnimationFrame (RaceControl.Tick >> RaceControlMsg)

        _ ->
            Sub.none



-- VIEW


view : Shared.Model -> Model -> View Msg
view ({ analysis_Wec, raceControl_Wec } as shared) { mode, leaderboardState } =
    { title = "Wec"
    , body =
        [ header shared
        , case mode of
            Leaderboard ->
                Leaderboard.view (config analysis_Wec) leaderboardState raceControl_Wec

            PositionHistory ->
                PositionHistoryChart.view raceControl_Wec
        ]
    }


header : Shared.Model -> Html Msg
header { eventSummary, raceControl_Wec } =
    Html.header [ css [ position sticky, top zero, backgroundColor (hsl 0 0 0.4) ] ]
        [ h1 [ css [ fontSize (em 1) ] ] [ text eventSummary.name ]
        , div [ css [ displayFlex, justifyContent spaceBetween ] ]
            [ nav []
                [ case raceControl_Wec.clock of
                    Initial ->
                        button [ onClick StartRace ] [ text "Start" ]

                    Started _ _ ->
                        button [ onClick PauseRace ] [ text "Pause" ]

                    Paused _ ->
                        button [ onClick StartRace ] [ text "Resume" ]

                    _ ->
                        text ""
                , case raceControl_Wec.clock of
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


config : Analysis -> Leaderboard.Config ViewModelItem Msg
config analysis =
    { toId = .metaData >> .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ intColumn { label = "", getter = .position }
        , carNumberColumn_Wec { getter = .metaData }
        , driverAndTeamColumn_Wec { getter = .metaData }
        , veryCustomColumn
            { label = "-"
            , getter = .metaData >> .carNumber >> Series.carImageUrl_2024 >> Maybe.map (\url -> img [ src url, css [ width (px 100) ] ] []) >> Maybe.withDefault (text "")
            , sorter = List.sortBy (.metaData >> .carNumber)
            }
        , intColumn { label = "Lap", getter = .lap }
        , customColumn
            { label = "Gap"
            , getter = .timing >> .gap >> Gap.toString
            , sorter = List.sortBy .position
            }
        , customColumn
            { label = "Interval"
            , getter = .timing >> .interval >> Gap.toString
            , sorter = List.sortBy .position
            }
        , currentLapColumn_Wec
            { getter = identity
            , sorter = List.sortBy (.currentLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , lastLapColumn_Wec
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
