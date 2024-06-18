module Page.Leaderboard exposing (Model, Msg, init, update, view)

import Data.F1.Decoder as F1
import Data.F1.Preprocess as F1
import Data.Leaderboard as Leaderboard
import Html.Styled as Html exposing (Html, input, text)
import Html.Styled.Attributes as Attributes exposing (type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Http
import Motorsport.Clock as Clock
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap exposing (Gap(..))
import Motorsport.Lap exposing (completedLapsAt, fastestLap, slowestLap)
import Motorsport.RaceControl as RaceControl
import Motorsport.Summary as Summary
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)
import UI.SortableData exposing (State, initialSort)



-- MODEL


type alias Model =
    { raceControl : RaceControl.Model
    , analysis :
        Maybe
            { fastestLapTime : Duration
            , slowestLapTime : Duration
            }
    , tableState : State
    , query : String
    }


init : ( Model, Cmd Msg )
init =
    ( { raceControl = RaceControl.empty
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
            ( { m | raceControl = RaceControl.init (Summary.calcLapTotal preprocessed) preprocessed }
            , Cmd.none
            )

        Loaded (Err _) ->
            ( m, Cmd.none )

        SetCount newCount_ ->
            let
                newCount =
                    Maybe.withDefault 0 (String.toInt newCount_)
            in
            ( if newCount >= 0 && newCount <= m.raceControl.lapTotal then
                let
                    raceControl =
                        RaceControl.update (RaceControl.SetCount newCount) m.raceControl
                in
                { m
                    | raceControl = raceControl
                    , analysis = Just (analysis_ raceControl)
                }

              else
                m
            , Cmd.none
            )

        NextLap ->
            ( if m.raceControl.raceClock.lapCount < m.raceControl.lapTotal then
                let
                    raceControl =
                        RaceControl.update RaceControl.NextLap m.raceControl
                in
                { m
                    | raceControl = raceControl
                    , analysis = Just (analysis_ raceControl)
                }

              else
                m
            , Cmd.none
            )

        PreviousLap ->
            let
                raceControl =
                    RaceControl.update RaceControl.PreviousLap m.raceControl
            in
            ( if m.raceControl.raceClock.lapCount > 0 then
                { m
                    | raceControl = raceControl
                    , analysis = Just (analysis_ raceControl)
                }

              else
                m
            , Cmd.none
            )

        SetTableState newState ->
            ( { m | tableState = newState }, Cmd.none )


analysis_ : RaceControl.Model -> { fastestLapTime : Duration, slowestLapTime : Duration }
analysis_ { raceClock, cars } =
    let
        completedLaps =
            List.map (.laps >> completedLapsAt raceClock) cars
    in
    { fastestLapTime = completedLaps |> fastestLap |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = completedLaps |> slowestLap |> Maybe.map .time |> Maybe.withDefault 0
    }



-- VIEW


view : Model -> List (Html Msg)
view { raceControl, analysis, tableState } =
    let
        { raceClock, lapTotal, cars } =
            raceControl

        leaderboard =
            Leaderboard.init raceClock cars
    in
    [ input
        [ type_ "range"
        , Attributes.max <| String.fromInt lapTotal
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
