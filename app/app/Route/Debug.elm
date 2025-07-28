module Route.Debug exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import Css exposing (backgroundColor, displayFlex, hsl, justifyContent, position, spaceBetween, sticky, top, zero)
import DataView
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Html.Styled exposing (div, header, input, nav, text)
import Html.Styled.Attributes as Attributes exposing (css, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import List.NonEmpty as NonEmpty
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (bestTimeColumn, carNumberColumn_Wec, customColumn, driverAndTeamColumn_Wec, initialSort, intColumn, lastLapColumn_F1, sectorTimeColumn)
import Motorsport.Ordering as Ordering
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel as ViewModel exposing (ViewModel, ViewModelItem)
import Motorsport.Utils exposing (compareBy)
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatefulRoute)
import Shared
import SortedList
import Task
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)
import View exposing (View)


type alias RouteParams =
    {}


route : StatefulRoute RouteParams Data ActionData Model Msg
route =
    RouteBuilder.single { head = \_ -> [], data = data }
        |> RouteBuilder.buildWithSharedState
            { init = init
            , update = update
            , subscriptions = \_ _ _ _ -> Sub.none
            , view = view
            }



-- MODEL


type alias Model =
    { leaderboardState : Leaderboard.Model
    , query : String
    }


init :
    App Data ActionData RouteParams
    -> Shared.Model
    -> ( Model, Effect Msg )
init app shared =
    ( { leaderboardState = initialSort "Position"
      , query = ""
      }
    , Effect.fromCmd
        (Task.succeed (Shared.FetchJson_Wec { season = "2024", event = "le_mans_24h" })
            |> Task.perform SharedMsg
        )
    )



-- UPDATE


type Msg
    = SharedMsg Shared.Msg
    | RaceControlMsg RaceControl.Msg
    | LeaderboardMsg Leaderboard.Msg


update :
    App Data ActionData RouteParams
    -> Shared.Model
    -> Msg
    -> Model
    -> ( Model, Effect Msg, Maybe Shared.Msg )
update app shared msg model =
    case msg of
        SharedMsg sharedMsg ->
            ( model, Effect.none, Just sharedMsg )

        RaceControlMsg raceControlMsg ->
            ( model, Effect.none, Just (Shared.RaceControlMsg raceControlMsg) )

        LeaderboardMsg leaderboardMsg ->
            ( { model | leaderboardState = Leaderboard.update leaderboardMsg model.leaderboardState }
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
view app { analysis, raceControl } { leaderboardState } =
    View.map PagesMsg.fromMsg
        { title = "Wec"
        , body =
            let
                { clock, lapTotal, lapCount } =
                    raceControl
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
                    [ div [] [ text "fastestLapTime: ", text (Duration.toString analysis.fastestLapTime) ]
                    , div [] [ text "slowestLapTime: ", text (Duration.toString analysis.slowestLapTime) ]
                    , div [] [ text "s1_fastest: ", text (Duration.toString analysis.sector_1_fastest) ]
                    , div [] [ text "s2_fastest: ", text (Duration.toString analysis.sector_2_fastest) ]
                    , div [] [ text "s3_fastest: ", text (Duration.toString analysis.sector_3_fastest) ]
                    ]
                ]
            , DataView.view (config analysis) leaderboardState (SortedList.toList (raceControlToLeaderboard raceControl).items)
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
                .currentLap
                    >> Maybe.map
                        (\{ sector_1, s1_best } ->
                            { time = sector_1
                            , personalBest = s1_best
                            , fastest = analysis.sector_1_fastest
                            , progress = 100
                            }
                        )
            }
        , customColumn
            { label = "S1 Best"
            , getter = .currentLap >> Maybe.map (.s1_best >> Duration.toString) >> Maybe.withDefault ""
            , sorter = compareBy (.currentLap >> Maybe.map .s1_best >> Maybe.withDefault 0)
            }
        , sectorTimeColumn
            { label = "S2"
            , getter =
                .currentLap
                    >> Maybe.map
                        (\{ sector_2, s2_best } ->
                            { time = sector_2
                            , personalBest = s2_best
                            , fastest = analysis.sector_2_fastest
                            , progress = 100
                            }
                        )
            }
        , customColumn
            { label = "S2 Best"
            , getter = .currentLap >> Maybe.map (.s2_best >> Duration.toString) >> Maybe.withDefault ""
            , sorter = compareBy (.currentLap >> Maybe.map .s2_best >> Maybe.withDefault 0)
            }
        , sectorTimeColumn
            { label = "S3"
            , getter =
                .currentLap
                    >> Maybe.map
                        (\{ sector_3, s3_best } ->
                            { time = sector_3
                            , personalBest = s3_best
                            , fastest = analysis.sector_3_fastest
                            , progress = 100
                            }
                        )
            }
        , customColumn
            { label = "S3 Best"
            , getter = .currentLap >> Maybe.map (.s3_best >> Duration.toString) >> Maybe.withDefault ""
            , sorter = compareBy (.currentLap >> Maybe.map .s3_best >> Maybe.withDefault 0)
            }
        , lastLapColumn_F1
            { getter = .lastLap
            , sorter = compareBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , bestTimeColumn { getter = .lastLap >> Maybe.map .best }
        ]
    }


raceControlToLeaderboard : RaceControl.Model -> ViewModel
raceControlToLeaderboard { lapCount, cars } =
    let
        sortedItems =
            cars
                |> NonEmpty.find (\car -> car.metaData.carNumber == "2")
                |> Maybe.map
                    (\car ->
                        car.laps
                            |> List.take lapCount
                            |> List.indexedMap
                                (\index lap ->
                                    { position = index + 1
                                    , positionInClass = index + 1
                                    , status = car.status
                                    , metaData = ViewModel.init_metaData car lap
                                    , lap = lap.lap
                                    , timing =
                                        { time = 0
                                        , sector = Nothing
                                        , miniSector = Nothing
                                        , gap = Gap.None
                                        , interval = Gap.None
                                        }
                                    , currentLap = Just lap
                                    , lastLap = Just lap
                                    , history = []
                                    }
                                )
                    )
                |> Maybe.withDefault []
                |> Ordering.byPosition

        leadLapNumber =
            sortedItems |> SortedList.head |> Maybe.map .lap |> Maybe.withDefault 0
    in
    { leadLapNumber = leadLapNumber
    , items = sortedItems
    , itemsByClass =
        sortedItems
            |> SortedList.gatherEqualsBy (.metaData >> .class)
            |> List.map (\( first, rest ) -> ( first.metaData.class, Ordering.byPosition (first :: SortedList.toList rest) ))
    }
