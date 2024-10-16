module Route.Debug exposing (ActionData, Data, Model, Msg(..), RouteParams, data, route)

import BackendTask exposing (BackendTask)
import Css exposing (backgroundColor, displayFlex, hsl, justifyContent, position, spaceBetween, sticky, top, zero)
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html.Styled as Html exposing (div, header, input, nav, text)
import Html.Styled.Attributes as Attributes exposing (css, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (Leaderboard, LeaderboardItem, bestTimeColumn, carNumberColumn_Wec, customColumn, driverAndTeamColumn_Wec, initialSort, intColumn, lastLapColumn, sectorTimeColumn)
import Motorsport.Leaderboard.Internal
import Motorsport.RaceControl as RaceControl
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App)
import Shared
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)
import View exposing (View)


type alias RouteParams =
    {}


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
    { leaderboardState : Leaderboard.Model
    , query : String
    }


init :
    App Data ActionData {}
    -> Shared.Model
    -> ( Model, Effect Msg )
init app shared =
    ( { leaderboardState = initialSort "Position"
      , query = ""
      }
    , Effect.none
    )



-- UPDATE


type Msg
    = RaceControlMsg RaceControl.Msg
    | LeaderboardMsg Leaderboard.Msg


update :
    App Data ActionData {}
    -> Shared.Model
    -> Msg
    -> Model
    -> ( Model, Effect Msg, Maybe Shared.Msg )
update app shared msg m =
    case msg of
        RaceControlMsg raceControlMsg ->
            ( m, Effect.none, Just (Shared.RaceControlMsg_Wec raceControlMsg) )

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
    App Data ActionData {}
    -> Shared.Model
    -> Model
    -> View (PagesMsg Msg)
view app { analysis_Wec, raceControl_Wec } { leaderboardState } =
    View.map PagesMsg.fromMsg
        { title = "Wec"
        , body =
            let
                { raceClock, lapTotal } =
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


config : Analysis -> Leaderboard.Config LeaderboardItem Msg
config analysis =
    { toId = .carNumber
    , toMsg = LeaderboardMsg
    , columns =
        [ intColumn { label = "", getter = .position }
        , carNumberColumn_Wec { carNumber = .carNumber, class = .class }
        , driverAndTeamColumn_Wec
        , intColumn { label = "Lap", getter = .lap }
        , sectorTimeColumn
            { label = "S1"
            , getter = \{ sector_1, s1_best } -> { time = sector_1, best = s1_best }
            , fastestSectorTime = analysis.sector_1_fastest
            }
        , customColumn
            { label = "S1 Best"
            , getter = .s1_best >> Duration.toString
            , sorter = List.sortBy (.s1_best >> Duration.toString)
            }
        , sectorTimeColumn
            { label = "S2"
            , getter = \{ sector_2, s2_best } -> { time = sector_2, best = s2_best }
            , fastestSectorTime = analysis.sector_2_fastest
            }
        , customColumn
            { label = "S2 Best"
            , getter = .s2_best >> Duration.toString
            , sorter = List.sortBy (.s2_best >> Duration.toString)
            }
        , sectorTimeColumn
            { label = "S3"
            , getter = \{ sector_3, s3_best } -> { time = sector_3, best = s3_best }
            , fastestSectorTime = analysis.sector_3_fastest
            }
        , customColumn
            { label = "S3 Best"
            , getter = .s3_best >> Duration.toString
            , sorter = List.sortBy (.s3_best >> Duration.toString)
            }
        , lastLapColumn
            { getter = identity
            , sorter = List.sortBy .lastLapTime
            , analysis = analysis
            }
        , bestTimeColumn { getter = .best }
        ]
    }


raceControlToLeaderboard : RaceControl.Model -> Leaderboard
raceControlToLeaderboard { raceClock, cars } =
    cars
        |> List.filter (\{ carNumber } -> carNumber == "2")
        |> List.head
        |> Maybe.map
            (\car ->
                car.laps
                    |> List.take raceClock.lapCount
                    |> List.indexedMap
                        (\index lap ->
                            { position = index + 1
                            , drivers =
                                car.drivers
                                    |> List.map
                                        (\{ name } ->
                                            { name = name
                                            , isCurrentDriver = name == lap.driver
                                            }
                                        )
                            , carNumber = car.carNumber
                            , class = car.class
                            , team = car.team
                            , lap = lap.lap
                            , gap = Gap.None
                            , interval = Gap.None
                            , sector_1 = Just lap.sector_1
                            , sector_2 = Just lap.sector_2
                            , sector_3 = Just lap.sector_3
                            , s1_best = lap.s1_best
                            , s2_best = lap.s2_best
                            , s3_best = lap.s3_best
                            , lastLapTime = lap.time
                            , best = lap.best
                            , history = []
                            }
                        )
            )
        |> Maybe.withDefault []
