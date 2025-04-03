module Route.Index exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import Css exposing (block, color, display, em, fontSize, inherit)
import Data.Series.Wec_2024 exposing (wec_2024)
import Data.Series.Wec_2025 exposing (wec_2025)
import FatalError exposing (FatalError)
import Html.Styled exposing (Html, a, h2, section, text)
import Html.Styled.Attributes exposing (css, href)
import PagesMsg exposing (PagesMsg)
import Route exposing (Route)
import RouteBuilder exposing (App, StatelessRoute)
import Shared
import View exposing (View)


type alias RouteParams =
    {}


route : StatelessRoute RouteParams Data ActionData
route =
    RouteBuilder.single { head = \_ -> [], data = data }
        |> RouteBuilder.buildNoState { view = view }


type alias Model =
    {}


type alias Msg =
    ()


type alias Data =
    {}


type alias ActionData =
    {}


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
        [ link { path = Route.GapChart, label = "Gap Chart" }
        , link { path = Route.LapTimeChart, label = "LapTime Chart" }
        , link { path = Route.LapTimeChartsByDriver, label = "LapTime Charts By Driver" }
        , link { path = Route.F1, label = "F1" }
        , section_ "WEC 2025"
            (List.map
                (\eventSummary ->
                    link
                        { label = eventSummary.name
                        , path = Route.Wec__Season___Event_ { season = "2025", event = eventSummary.id }
                        }
                )
                wec_2025
            )
        , section_ "WEC 2024"
            (List.map
                (\eventSummary ->
                    link
                        { label = eventSummary.name
                        , path = Route.Wec__Season___Event_ { season = "2024", event = eventSummary.id }
                        }
                )
                wec_2024
            )
        ]
    }


section_ : String -> List (Html msg) -> Html msg
section_ title children =
    section []
        (h2 [ css [ fontSize (em 1) ] ] [ text title ]
            :: children
        )


link : { label : String, path : Route } -> Html msg
link props =
    a
        [ href (Route.toString props.path)
        , css [ display block, color inherit ]
        ]
        [ text props.label ]
