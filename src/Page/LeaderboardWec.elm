module Page.LeaderboardWec exposing (Model, Msg, init, update, view)

import Css exposing (color, hex)
import Effect exposing (Effect)
import Html.Styled as Html exposing (Html, input, span, text)
import Html.Styled.Attributes as Attributes exposing (css, type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Motorsport.Analysis as Analysis
import Motorsport.Clock as Clock
import Motorsport.Duration as Duration
import Motorsport.Gap as Gap exposing (Gap(..))
import Motorsport.LapStatus exposing (LapStatus(..), lapStatus)
import Motorsport.Leaderboard as Leaderboard exposing (LeaderboardItem, customColumn, gap_, histogram, initialSort, intColumn, performance, stringColumn, veryCustomColumn)
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
    , Effect.fetchCsv "/static/23_Analysis_Race_Hour 24.csv"
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
    , Leaderboard.table (config raceControl) leaderboard leaderboardData
    ]


config : RaceControl.Model -> Leaderboard.Config LeaderboardItem Msg
config raceControl =
    let
        analysis =
            Analysis.fromRaceControl raceControl

        coefficient =
            1.2
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
        , veryCustomColumn
            { label = "Gap"
            , getter =
                \{ gap } ->
                    case gap of
                        None ->
                            text "-"

                        Seconds duration ->
                            gap_ duration

                        Laps _ ->
                            text "-"
            , sorter = List.sortBy .position
            }
        , veryCustomColumn
            { label = "Time"
            , getter =
                \item ->
                    span
                        [ css
                            [ color <|
                                hex <|
                                    case lapStatus { time = analysis.fastestLapTime } item of
                                        Fastest ->
                                            "#F0F"

                                        PersonalBest ->
                                            "#0C0"

                                        Normal ->
                                            "inherit"
                            ]
                        ]
                        [ text <| Duration.toString item.time ]
            , sorter = List.sortBy .time
            }
        , veryCustomColumn
            { label = "Time"
            , getter = .history >> performance raceControl.raceClock analysis coefficient
            , sorter = List.sortBy .time
            }
        , veryCustomColumn
            { label = "Histogram"
            , getter = .history >> histogram analysis coefficient
            , sorter = List.sortBy .time
            }
        ]
    }
