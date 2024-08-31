module Route.GapChart exposing (ActionData, Data, Model, Msg, RouteParams, data, route)

import BackendTask exposing (BackendTask)
import FatalError exposing (FatalError)
import Motorsport.Chart.GapChart as GapChart
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatelessRoute)
import Shared
import View exposing (View)


type alias RouteParams =
    {}


type alias Model =
    {}


type alias Msg =
    ()


type alias Data =
    {}


type alias ActionData =
    {}


route : StatelessRoute RouteParams Data ActionData
route =
    RouteBuilder.single { head = \_ -> [], data = data }
        |> RouteBuilder.buildNoState { view = view }


data : BackendTask FatalError Data
data =
    BackendTask.succeed Data


view :
    App Data ActionData RouteParams
    -> Shared.Model
    -> View (PagesMsg Msg)
view app { analysis, raceControl_F1 } =
    { title = "GapChart"
    , body = [ GapChart.view analysis raceControl_F1 ]
    }
