module Route.Index exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import FatalError exposing (FatalError)
import Html.Styled as Html exposing (a, br, text)
import Html.Styled.Attributes exposing (href)
import PagesMsg exposing (PagesMsg)
import Route
import RouteBuilder exposing (App, StatelessRoute)
import Shared
import View exposing (View)


type alias Model =
    {}


type alias Msg =
    ()


type alias RouteParams =
    {}


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
view app shared =
    { title = "Race Analysis"
    , body =
        [ a [ href "/gap-chart" ] [ text "Gap Chart" ]
        , br [] []
        , a [ href "/lap-time-chart" ] [ text "LapTime Chart" ]
        , br [] []
        , a [ href "/lap-time-charts-by-driver" ] [ text "LapTime Charts By Driver" ]
        , br [] []
        , a [ href "/f1" ] [ text "F1" ]
        , br [] []
        , a [ href "/wec" ] [ text "Wec" ]
        ]
    }
