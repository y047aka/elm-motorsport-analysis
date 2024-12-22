module Pages.Home_ exposing (page)

import Html.Styled exposing (a, br, text)
import Html.Styled.Attributes exposing (href)
import View exposing (View)


page : View msg
page =
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
