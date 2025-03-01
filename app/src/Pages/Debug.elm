module Pages.Debug exposing (Model, Msg, page)

import Css exposing (backgroundColor, displayFlex, hsl, justifyContent, position, spaceBetween, sticky, top, zero)
import Effect exposing (Effect)
import Html.Styled exposing (div, header, input, nav, text)
import Html.Styled.Attributes as Attributes exposing (css, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (bestTimeColumn, carNumberColumn_Wec, customColumn, driverAndTeamColumn_Wec, initialSort, intColumn, lastLapColumn_F1, sectorTimeColumn)
import Motorsport.Leaderboard.Internal
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel as ViewModel exposing (ViewModel, ViewModelItem)
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
    { leaderboardState : Leaderboard.Model
    , query : String
    }


init : () -> ( Model, Effect Msg )
init () =
    ( { leaderboardState = initialSort "Position"
      , query = ""
      }
    , Effect.fetchJson_Wec { season = "2024", event = "le_mans_24h" }
    )



-- UPDATE


type Msg
    = RaceControlMsg RaceControl.Msg
    | LeaderboardMsg Leaderboard.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    case msg of
        RaceControlMsg raceControlMsg ->
            ( m, Effect.updateRaceControl_Wec raceControlMsg )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboardState = Leaderboard.update leaderboardMsg m.leaderboardState }
            , Effect.none
            )



-- VIEW


view : Shared.Model -> Model -> View Msg
view { analysis_Wec, raceControl_Wec } { leaderboardState } =
    { title = "Wec"
    , body =
        let
            { clock, lapTotal, lapCount } =
                raceControl_Wec
        in
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
            , div []
                [ div [] [ text "fastestLapTime: ", text (Duration.toString analysis_Wec.fastestLapTime) ]
                , div [] [ text "slowestLapTime: ", text (Duration.toString analysis_Wec.slowestLapTime) ]
                , div [] [ text "s1_fastest: ", text (Duration.toString analysis_Wec.sector_1_fastest) ]
                , div [] [ text "s2_fastest: ", text (Duration.toString analysis_Wec.sector_2_fastest) ]
                , div [] [ text "s3_fastest: ", text (Duration.toString analysis_Wec.sector_3_fastest) ]
                ]
            ]
        , Motorsport.Leaderboard.Internal.table (config analysis_Wec) leaderboardState (raceControlToLeaderboard raceControl_Wec)
        ]
    }


config : Analysis -> Leaderboard.Config ViewModelItem Msg
config analysis =
    { toId = .metaData >> .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ intColumn { label = "", getter = .position }
        , carNumberColumn_Wec 2025 { getter = .metaData }
        , driverAndTeamColumn_Wec { getter = .metaData }
        , intColumn { label = "Lap", getter = .lap }
        , sectorTimeColumn
            { label = "S1"
            , getter =
                .timing
                    >> .sector_1
                    >> Maybe.map
                        (\{ time, personalBest, inProgress } ->
                            { time = time
                            , personalBest = personalBest
                            , overallBest = analysis.sector_1_fastest
                            , inProgress = inProgress
                            }
                        )
            }
        , customColumn
            { label = "S1 Best"
            , getter = .timing >> .sector_1 >> Maybe.map (.personalBest >> Duration.toString) >> Maybe.withDefault ""
            , sorter = List.sortBy (.timing >> .sector_1 >> Maybe.map (.personalBest >> Duration.toString) >> Maybe.withDefault "0")
            }
        , sectorTimeColumn
            { label = "S2"
            , getter =
                .timing
                    >> .sector_2
                    >> Maybe.map
                        (\{ time, personalBest, inProgress } ->
                            { time = time
                            , personalBest = personalBest
                            , overallBest = analysis.sector_2_fastest
                            , inProgress = inProgress
                            }
                        )
            }
        , customColumn
            { label = "S2 Best"
            , getter = .timing >> .sector_2 >> Maybe.map (.personalBest >> Duration.toString) >> Maybe.withDefault ""
            , sorter = List.sortBy (.timing >> .sector_2 >> Maybe.map (.personalBest >> Duration.toString) >> Maybe.withDefault "0")
            }
        , sectorTimeColumn
            { label = "S3"
            , getter =
                .timing
                    >> .sector_3
                    >> Maybe.map
                        (\{ time, personalBest, inProgress } ->
                            { time = time
                            , personalBest = personalBest
                            , overallBest = analysis.sector_3_fastest
                            , inProgress = inProgress
                            }
                        )
            }
        , customColumn
            { label = "S3 Best"
            , getter = .timing >> .sector_3 >> Maybe.map (.personalBest >> Duration.toString) >> Maybe.withDefault ""
            , sorter = List.sortBy (.timing >> .sector_3 >> Maybe.map (.personalBest >> Duration.toString) >> Maybe.withDefault "0")
            }
        , lastLapColumn_F1
            { getter = .lastLap
            , sorter = List.sortBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , bestTimeColumn { getter = .lastLap >> Maybe.map .best }
        ]
    }


raceControlToLeaderboard : RaceControl.Model -> ViewModel
raceControlToLeaderboard { lapCount, cars } =
    cars
        |> List.filter (\{ carNumber } -> carNumber == "2")
        |> List.head
        |> Maybe.map
            (\car ->
                car.laps
                    |> List.take lapCount
                    |> List.indexedMap
                        (\index lap ->
                            { position = index + 1
                            , metaData = ViewModel.init_metaData car lap
                            , lap = lap.lap
                            , timing =
                                { time = 0
                                , sector_1 = Just { time = lap.sector_1, personalBest = lap.s1_best, inProgress = False }
                                , sector_2 = Just { time = lap.sector_2, personalBest = lap.s2_best, inProgress = False }
                                , sector_3 = Just { time = lap.sector_3, personalBest = lap.s3_best, inProgress = False }
                                , gap = Gap.None
                                , interval = Gap.None
                                }
                            , currentLap = Nothing
                            , lastLap = Just lap
                            , history = []
                            }
                        )
            )
        |> Maybe.withDefault []
