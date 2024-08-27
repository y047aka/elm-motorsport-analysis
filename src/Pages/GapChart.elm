module Pages.GapChart exposing (Model, Msg, page)

import Chart.GapChart as GapChart
import Effect exposing (Effect)
import Page exposing (Page)
import Route exposing (Route)
import Shared
import View exposing (View)


page : Shared.Model -> Route () -> Page Model Msg
page shared route =
    Page.new
        { init = init
        , update = update
        , view = view shared
        , subscriptions = \_ -> Sub.none
        }



-- MODEL


type alias Model =
    {}


init : () -> ( Model, Effect Msg )
init () =
    ( {}, Effect.fetchJson "/static/lapTimes.json" )



-- UPDATE


type Msg
    = NoOp


update : Msg -> Model -> ( Model, Effect Msg )
update msg model =
    ( model, Effect.none )



-- VIEW


view : Shared.Model -> Model -> View Msg
view { analysis, raceControl } _ =
    { title = "GapChart"
    , body = [ GapChart.view analysis raceControl ]
    }
