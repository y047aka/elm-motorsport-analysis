module Page.Leaderboard exposing (Model, Msg, init, update, view)

import Data.F1.Decoder as F1
import Data.F1.Preprocess as F1
import Data.Leaderboard exposing (Leaderboard, leaderboard)
import Html.Styled as Html exposing (Html, input, text)
import Html.Styled.Attributes as Attributes exposing (type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Http
import Motorsport.Clock as Clock exposing (Clock, countDown, countUp)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap exposing (Gap(..))
import Motorsport.Lap exposing (Lap, completedLapsAt, fastestLap, slowestLap)
import Motorsport.Summary as Summary exposing (Summary)
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)
import UI.SortableData exposing (State, initialSort)
import View.Leaderboard as Leaderboard



-- MODEL


type alias Model =
    { raceClock : Clock
    , preprocessed : Preprocessed
    , summary : Summary
    , leaderboard : Leaderboard
    , analysis :
        Maybe
            { fastestLapTime : Duration
            , slowestLapTime : Duration
            }
    , tableState : State
    , query : String
    }


type alias Preprocessed =
    List (List Lap)


init : ( Model, Cmd Msg )
init =
    ( { raceClock = Clock.init
      , preprocessed = []
      , summary = Summary.init
      , leaderboard = []
      , analysis = Nothing
      , tableState = initialSort "Position"
      , query = ""
      }
    , fetchJson
    )


fetchJson : Cmd Msg
fetchJson =
    Http.get
        { url = "/static/lapTimes.json"
        , expect = Http.expectJson Loaded F1.decoder
        }



-- UPDATE


type Msg
    = Loaded (Result Http.Error (List F1.Car))
    | SetCount String
    | CountUp
    | CountDown
    | SetTableState State


update : Msg -> Model -> ( Model, Cmd Msg )
update msg m =
    case msg of
        Loaded (Ok decoded) ->
            let
                preprocessed =
                    F1.preprocess decoded
            in
            ( { m
                | raceClock = Clock.init
                , preprocessed = preprocessed
                , summary = { lapTotal = Summary.calcLapTotal preprocessed }
                , leaderboard =
                    List.indexedMap
                        (\index laps ->
                            let
                                { carNumber, driver } =
                                    List.head laps
                                        |> Maybe.map (\l -> { carNumber = l.carNumber, driver = l.driver })
                                        |> Maybe.withDefault { carNumber = "000", driver = "" }
                            in
                            { position = index + 1
                            , carNumber = carNumber
                            , driver = driver
                            , lap = 0
                            , gap = None
                            , time = 0
                            , best = 0
                            , history = []
                            }
                        )
                        preprocessed
              }
            , Cmd.none
            )

        Loaded (Err _) ->
            ( m, Cmd.none )

        SetCount newCount ->
            ( if m.raceClock.lapCount < m.summary.lapTotal then
                let
                    updatedClock =
                        Clock.initWithCount (Maybe.withDefault 0 (String.toInt newCount)) m.preprocessed
                in
                { m
                    | raceClock = updatedClock
                    , leaderboard = leaderboard updatedClock m.preprocessed
                    , analysis = Just (analysis_ updatedClock m.preprocessed)
                }

              else
                m
            , Cmd.none
            )

        CountUp ->
            ( if m.raceClock.lapCount < m.summary.lapTotal then
                let
                    updatedClock =
                        countUp m.preprocessed m.raceClock
                in
                { m
                    | raceClock = updatedClock
                    , leaderboard = leaderboard updatedClock m.preprocessed
                    , analysis = Just (analysis_ updatedClock m.preprocessed)
                }

              else
                m
            , Cmd.none
            )

        CountDown ->
            let
                updatedClock =
                    countDown m.preprocessed m.raceClock
            in
            ( { m
                | raceClock = updatedClock
                , leaderboard = leaderboard updatedClock m.preprocessed
                , analysis = Just (analysis_ updatedClock m.preprocessed)
              }
            , Cmd.none
            )

        SetTableState newState ->
            ( { m | tableState = newState }, Cmd.none )


analysis_ : Clock -> Preprocessed -> { fastestLapTime : Duration, slowestLapTime : Duration }
analysis_ clock preprocessed =
    let
        completedLaps =
            List.map (completedLapsAt clock) preprocessed
    in
    { fastestLapTime = completedLaps |> fastestLap |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = completedLaps |> slowestLap |> Maybe.map .time |> Maybe.withDefault 0
    }



-- VIEW


view : Model -> List (Html Msg)
view { raceClock, leaderboard, analysis, tableState, summary } =
    [ input
        [ type_ "range"
        , Attributes.max <| String.fromInt summary.lapTotal
        , value (String.fromInt raceClock.lapCount)
        , onInput SetCount
        ]
        []
    , labeledButton []
        [ button [ onClick CountDown ] [ text "-" ]
        , basicLabel [] [ text (String.fromInt raceClock.lapCount) ]
        , button [ onClick CountUp ] [ text "+" ]
        ]
    , text <| Clock.toString raceClock
    , Leaderboard.view tableState
        raceClock
        (Maybe.withDefault { fastestLapTime = 0, slowestLapTime = 0 } analysis)
        SetTableState
        1.1
        leaderboard
    ]
