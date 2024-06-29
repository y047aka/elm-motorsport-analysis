module Page.Leaderboard exposing (Model, Msg, init, update, view)

import Effect exposing (Effect)
import Html.Styled as Html exposing (Html, input, text)
import Html.Styled.Attributes as Attributes exposing (type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Analysis as Analysis
import Motorsport.Clock as Clock
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (LeaderboardItem, customColumn, gapPreviewColumn, histogramColumn, initialSort, intColumn, performanceColumn, stringColumn, timeColumn)
import Motorsport.RaceControl as RaceControl
import Shared
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)



-- MODEL


type alias Model =
    { leaderboard : Leaderboard.Model
    , query : String
    }


init : ( Model, Effect Msg )
init =
    ( { leaderboard = initialSort "Position"
      , query = ""
      }
    , Effect.fetchJson "/static/lapTimes.json"
    )



-- UPDATE


type Msg
    = RaceControlMsg RaceControl.Msg
    | LeaderboardMsg Leaderboard.Msg


update : Msg -> Model -> ( Model, Effect Msg )
update msg m =
    case msg of
        RaceControlMsg raceControlMsg ->
            ( m, Effect.updateRaceControl raceControlMsg )

        LeaderboardMsg leaderboardMsg ->
            ( { m | leaderboard = Leaderboard.update leaderboardMsg m.leaderboard }
            , Effect.none
            )



-- VIEW


view : Shared.Model -> Model -> List (Html Msg)
view { raceControl } { leaderboard } =
    let
        { raceClock, lapTotal, cars } =
            raceControl

        leaderboardData =
            Leaderboard.init raceClock cars
    in
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
    , Leaderboard.view (config raceControl) leaderboard leaderboardData
    ]


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
        , gapPreviewColumn
            { label = "Gap"
            , getter = identity
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
            , raceClock = raceControl.raceClock
            , analysis = analysis
            , coefficient = 1.2
            }
        , histogramColumn
            { getter = .history
            , sorter = List.sortBy .time
            , analysis = analysis
            , coefficient = 1.2
            }
        ]
    }
