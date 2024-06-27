module Page.Leaderboard exposing (Model, Msg, init, update, view)

import Data.F1.Decoder as F1
import Data.F1.Preprocess as F1
import Data.Leaderboard as Leaderboard
import Html.Styled as Html exposing (Html, input, text)
import Html.Styled.Attributes as Attributes exposing (type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Http
import Motorsport.Analysis as Analysis
import Motorsport.Clock as Clock
import Motorsport.RaceControl as RaceControl
import UI.Button exposing (button, labeledButton)
import UI.Label exposing (basicLabel)
import UI.SortableData exposing (State, initialSort)



-- MODEL


type alias Model =
    { raceControl : RaceControl.Model
    , tableState : State
    , query : String
    }


init : ( Model, Cmd Msg )
init =
    ( { raceControl = RaceControl.empty
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
    | RaceControlMsg RaceControl.Msg
    | SetTableState State


update : Msg -> Model -> ( Model, Cmd Msg )
update msg m =
    case msg of
        Loaded (Ok decoded) ->
            let
                preprocessed =
                    F1.preprocess decoded
            in
            ( { m | raceControl = RaceControl.init preprocessed }
            , Cmd.none
            )

        Loaded (Err _) ->
            ( m, Cmd.none )

        RaceControlMsg raceControlMsg ->
            ( { m | raceControl = RaceControl.update raceControlMsg m.raceControl }, Cmd.none )

        SetTableState newState ->
            ( { m | tableState = newState }, Cmd.none )



-- VIEW


view : Model -> List (Html Msg)
view { raceControl, tableState } =
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
        , onInput (String.toInt >> Maybe.withDefault 0 >> RaceControl.SetCount >> RaceControlMsg)
        ]
        []
    , labeledButton []
        [ button [ onClick (RaceControlMsg RaceControl.PreviousLap) ] [ text "-" ]
        , basicLabel [] [ text (String.fromInt raceClock.lapCount) ]
        , button [ onClick (RaceControlMsg RaceControl.NextLap) ] [ text "+" ]
        ]
    , text <| Clock.toString raceClock
    , Leaderboard.view tableState
        raceClock
        (Analysis.fromRaceControl raceControl)
        SetTableState
        1.1
        leaderboard
    ]
