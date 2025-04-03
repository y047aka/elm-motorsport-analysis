module Route.GapChart exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Motorsport.Chart.GapChart as GapChart
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatefulRoute)
import Shared
import Task
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
        (Task.succeed (Shared.FetchJson "/static/lapTimes.json")
            |> Task.perform SharedMsg
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
    { title = "GapChart"
    , body = [ GapChart.view analysis_F1 raceControl_F1 ]
    }
