module Pages.Home_ exposing (page)

import Css exposing (block, color, display, em, fontSize, inherit)
import Html.Styled exposing (Html, a, h2, section, text)
import Html.Styled.Attributes exposing (css, href)
import Route.Path as Path exposing (Path(..))
import View exposing (View)


page : View msg
page =
    { title = "Race Analysis"
    , body =
        [ link { path = GapChart, label = "Gap Chart" }
        , link { path = LapTimeChart, label = "LapTime Chart" }
        , link { path = LapTimeChartsByDriver, label = "LapTime Charts By Driver" }
        , link { path = F1, label = "F1" }
        , section []
            [ h2 [ css [ fontSize (em 1) ] ] [ text "WEC 2024" ]
            , link { path = Wec_Id_ { id = "23_Analysis_Race_Hour 24" }, label = "24 Hours of Le Mans" }
            , link { path = Wec_Id_ { id = "23_Analysis_Race_Hour 6" }, label = "6 Hours of Fuji" }
            , link { path = Wec_Id_ { id = "23_Analysis_Race_Hour 8" }, label = "8 Hours of Bahrain" }
            ]
        ]
    }


link : { path : Path, label : String } -> Html msg
link props =
    a
        [ href (Path.toString props.path)
        , css [ display block, color inherit ]
        ]
        [ text props.label ]
