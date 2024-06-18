module Page.Leaderboard exposing (Model, Msg, init, update, view)

import Data.F1.Decoder as F1
import Data.F1.Preprocess as F1
import Data.Leaderboard as Leaderboard exposing (Leaderboard)
import Html.Styled as Html exposing (Html, input, text)
import Html.Styled.Attributes as Attributes exposing (type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Http
import Motorsport.Car exposing (Car)
import Motorsport.Clock as Clock exposing (Clock, jumpToNextLap, jumpToPreviousLap)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap exposing (Gap(..))
import Motorsport.Lap exposing (completedLapsAt, fastestLap, slowestLap)
import Motorsport.Summary as Summary exposing (Summary)
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)
import UI.SortableData exposing (State, initialSort)



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
    List Car


init : ( Model, Cmd Msg )
init =
    ( { raceClock = Clock.init
      , preprocessed = []
      , summary = Summary.init
      , leaderboard = Leaderboard.empty
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
    | NextLap
    | PreviousLap
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
                        (\index { carNumber, driverName } ->
                            { position = index + 1
                            , carNumber = carNumber
                            , driver = driverName
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
                        Clock.initWithCount (Maybe.withDefault 0 (String.toInt newCount)) (List.map .laps m.preprocessed)
                in
                { m
                    | raceClock = updatedClock
                    , leaderboard = Leaderboard.init updatedClock m.preprocessed
                    , analysis = Just (analysis_ updatedClock m.preprocessed)
                }

              else
                m
            , Cmd.none
            )

        NextLap ->
            ( if m.raceClock.lapCount < m.summary.lapTotal then
                let
                    updatedClock =
                        jumpToNextLap (List.map .laps m.preprocessed) m.raceClock
                in
                { m
                    | raceClock = updatedClock
                    , leaderboard = Leaderboard.init updatedClock m.preprocessed
                    , analysis = Just (analysis_ updatedClock m.preprocessed)
                }

              else
                m
            , Cmd.none
            )

        PreviousLap ->
            let
                updatedClock =
                    jumpToPreviousLap (List.map .laps m.preprocessed) m.raceClock
            in
            ( { m
                | raceClock = updatedClock
                , leaderboard = Leaderboard.init updatedClock m.preprocessed
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
            List.map (.laps >> completedLapsAt clock) preprocessed
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
        [ button [ onClick PreviousLap ] [ text "-" ]
        , basicLabel [] [ text (String.fromInt raceClock.lapCount) ]
        , button [ onClick NextLap ] [ text "+" ]
        ]
    , text <| Clock.toString raceClock
    , Leaderboard.view tableState
        raceClock
        (Maybe.withDefault { fastestLapTime = 0, slowestLapTime = 0 } analysis)
        SetTableState
        1.1
        leaderboard
    ]
