module Page.LapTimeTable exposing (Model, Msg, init, update, view)

import Data.LapTime as LapTime exposing (LapTime)
import Data.LapTimes exposing (LapTimes, lapTimesDecoder)
import Html.Styled as Html exposing (Html)
import Http
import UI.SortableData exposing (State, initialSort, intColumn, stringColumn, table)



-- MODEL


type alias Model =
    { lapTimes : LapTimes
    , tableState : State
    , query : String
    }


init : ( Model, Cmd Msg )
init =
    ( { lapTimes = []
      , tableState = initialSort "Driver"
      , query = ""
      }
    , fetchJson
    )


fetchJson : Cmd Msg
fetchJson =
    Http.get
        { url = "/static/lapTimes.json"
        , expect = Http.expectJson Loaded lapTimesDecoder
        }



-- UPDATE


type Msg
    = Loaded (Result Http.Error LapTimes)
    | SetTableState State


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Loaded (Ok lapTimes) ->
            ( { model | lapTimes = lapTimes }, Cmd.none )

        Loaded (Err _) ->
            ( model, Cmd.none )

        SetTableState newState ->
            ( { model | tableState = newState }, Cmd.none )



-- VIEW


view : Model -> List (Html Msg)
view model =
    [ sortableTable model <|
        List.concatMap
            (\car ->
                List.map
                    (\{ lap, time } ->
                        { carNumber = car.carNumber
                        , driverName = car.driver.name
                        , lap = lap
                        , time = time
                        }
                    )
                    car.laps
            )
            model.lapTimes
    ]


type alias LapData =
    { carNumber : String
    , driverName : String
    , lap : Int
    , time : LapTime
    }


sortableTable : Model -> List LapData -> Html Msg
sortableTable { tableState } =
    let
        config =
            { toId = .lap >> String.fromInt
            , toMsg = SetTableState
            , columns =
                [ stringColumn { label = "Car", getter = .carNumber }
                , stringColumn { label = "Driver", getter = .driverName }
                , intColumn { label = "Lap", getter = .lap }
                , stringColumn { label = "Time", getter = .time >> LapTime.toString }
                ]
            }
    in
    table config tableState
