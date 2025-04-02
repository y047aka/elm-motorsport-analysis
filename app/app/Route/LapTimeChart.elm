module Route.LapTimeChart exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import Data.F1.Decoder as F1
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Http
import Motorsport.Chart.LapTimeChart as LapTimeChart
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatefulRoute)
import Shared
import View exposing (View)


type alias RouteParams =
    {}


route : StatefulRoute RouteParams Data ActionData Model Msg
route =
    RouteBuilder.single { head = \_ -> [], data = data }
        |> RouteBuilder.buildWithSharedState
            { init = init
            , update = update
            , subscriptions = \_ _ _ _ -> Sub.none
            , view = view
            }



-- MODEL


type alias Model =
    {}


init :
    App Data ActionData RouteParams
    -> Shared.Model
    -> ( Model, Effect Msg )
init app shared =
    ( {}
    , Effect.fromCmd
        (Http.get
            { url = "/static/lapTimes.json"
            , expect = Http.expectJson (Shared.JsonLoaded >> SharedMsg) F1.decoder
            }
        )
    )



-- UPDATE


type Msg
    = SharedMsg Shared.Msg


update :
    App Data ActionData RouteParams
    -> Shared.Model
    -> Msg
    -> Model
    -> ( Model, Effect Msg, Maybe Shared.Msg )
update app shared msg model =
    case msg of
        SharedMsg sharedMsg ->
            ( model, Effect.none, Just sharedMsg )



-- DATA


type alias Data =
    {}


type alias ActionData =
    {}


data : BackendTask FatalError Data
data =
    BackendTask.succeed {}



-- VIEW


view :
    App Data ActionData RouteParams
    -> Shared.Model
    -> Model
    -> View (PagesMsg Msg)
view app { analysis_F1, raceControl_F1 } _ =
    { title = "LapTime Chart"
    , body = [ LapTimeChart.view analysis_F1 raceControl_F1 ]
    }
