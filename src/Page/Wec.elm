module Page.Wec exposing (Model, Msg, init, update, view)

import Chart.Chart as Chart
import Effect exposing (Effect)
import Html.Styled as Html exposing (Html)
import Shared



-- MODEL


type alias Model =
    {}


init : ( Model, Effect Msg )
init =
    ( {}
    , Effect.fetchCsv "/static/23_Analysis_Race_Hour 24.csv"
    )



-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Effect.none )



-- VIEW


view : Shared.Model -> Model -> List (Html msg)
view shared _ =
    [ Chart.view shared ]
