module Page.LapTimeTable exposing (Model, Msg, init, update, view)

import Chart.LapTimes as LapTimes
import Data.LapTimes exposing (LapTimes, lapTimesDecoder)
import Html.Styled as Html exposing (Html)
import Http



-- MODEL


type alias Model =
    { lapTimes : LapTimes }


init : ( Model, Cmd Msg )
init =
    ( { lapTimes = [] }, fetchJson )


fetchJson : Cmd Msg
fetchJson =
    Http.get
        { url = "/static/lapTimes.json"
        , expect = Http.expectJson Loaded lapTimesDecoder
        }



-- UPDATE


type Msg
    = Loaded (Result Http.Error LapTimes)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Loaded (Ok lapTimes) ->
            ( { model | lapTimes = lapTimes }, Cmd.none )

        Loaded (Err _) ->
            ( model, Cmd.none )



-- VIEW


view : Model -> List (Html msg)
view { lapTimes } =
    [ LapTimes.view lapTimes ]