module Pages.Home_ exposing (page)

import Html.Styled exposing (Attribute, a, br, text)
import Html.Styled.Attributes
import Route.Path as Path exposing (Path(..))
import View exposing (View)


page : View msg
page =
    { title = "Race Analysis"
    , body =
        [ a [ href GapChart ] [ text "Gap Chart" ]
        , br [] []
        , a [ href LapTimeChart ] [ text "LapTime Chart" ]
        , br [] []
        , a [ href LapTimeChartsByDriver ] [ text "LapTime Charts By Driver" ]
        , br [] []
        , a [ href F1 ] [ text "F1" ]
        , br [] []
        , a [ href (Wec_Id_ { id = "23_Analysis_Race_Hour 24" }) ] [ text "24 Hours of Le Mans - WEC 2024" ]
        , br [] []
        , a [ href (Wec_Id_ { id = "23_Analysis_Race_Hour 6" }) ] [ text "6 Hours of Fuji - WEC 2024" ]
        , br [] []
        , a [ href (Wec_Id_ { id = "23_Analysis_Race_Hour 8" }) ] [ text "8 Hours of Bahrain - WEC 2024" ]
        ]
    }


href : Path -> Attribute msg
href path =
    Html.Styled.Attributes.href (Path.toString path)
