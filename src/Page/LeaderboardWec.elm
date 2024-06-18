module Page.LeaderboardWec exposing (Model, Msg, init, update, view)

import Csv.Decode as Decode exposing (Decoder, FieldNames(..))
import Data.Leaderboard as Leaderboard
import Data.Wec.Decoder as Wec
import Data.Wec.Preprocess as Wec
import Html.Styled as Html exposing (Html, input, text)
import Html.Styled.Attributes as Attributes exposing (type_, value)
import Html.Styled.Events exposing (onClick, onInput)
import Http exposing (Error(..), Expect, Response(..), expectStringResponse)
import Motorsport.Car exposing (Car)
import Motorsport.Clock as Clock exposing (Clock)
import Motorsport.Duration exposing (Duration)
import Motorsport.Lap exposing (completedLapsAt, fastestLap, slowestLap)
import Motorsport.RaceControl as RaceControl
import Motorsport.Summary as Summary
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
    , fetchCsv
    )


fetchCsv : Cmd Msg
fetchCsv =
    Http.get
        { url = "/static/23_Analysis_Race_Hour 24.csv"
        , expect = expectCsv Loaded Wec.lapDecoder
        }


expectCsv : (Result Error (List a) -> msg) -> Decoder a -> Expect msg
expectCsv toMsg decoder =
    let
        resolve : (body -> Result String (List a)) -> Response body -> Result Error (List a)
        resolve toResult response =
            case response of
                BadUrl_ url ->
                    Err (BadUrl url)

                Timeout_ ->
                    Err Timeout

                NetworkError_ ->
                    Err NetworkError

                BadStatus_ metadata _ ->
                    Err (BadStatus metadata.statusCode)

                GoodStatus_ _ body ->
                    Result.mapError BadBody (toResult body)
    in
    expectStringResponse toMsg <|
        resolve
            (Decode.decodeCustom { fieldSeparator = ';' } FieldNamesFromFirstRow decoder
                >> Result.mapError Decode.errorToString
            )



-- UPDATE


type Msg
    = Loaded (Result Http.Error (List Wec.Lap))
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
                    Wec.preprocess decoded
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
            ( { m | raceControl = RaceControl.update (RaceControl.SetCount newCount) m.raceControl }
            , Cmd.none
            )

        NextLap ->
            ( { m | raceControl = RaceControl.update RaceControl.NextLap m.raceControl }
            , Cmd.none
            )

        PreviousLap ->
            ( { m | raceControl = RaceControl.update RaceControl.PreviousLap m.raceControl }
            , Cmd.none
            )

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
        (analysis raceControl)
        SetTableState
        1.2
        leaderboard
    ]


analysis : { a | raceClock : Clock, cars : List Car } -> { fastestLapTime : Duration, slowestLapTime : Duration }
analysis { raceClock, cars } =
    let
        completedLaps =
            List.map (.laps >> completedLapsAt raceClock) cars
    in
    { fastestLapTime = completedLaps |> fastestLap |> Maybe.map .time |> Maybe.withDefault 0
    , slowestLapTime = completedLaps |> slowestLap |> Maybe.map .time |> Maybe.withDefault 0
    }
