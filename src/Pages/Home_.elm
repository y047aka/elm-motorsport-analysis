module Pages.Home_ exposing (page)

import Html exposing (a, br, text)
import Html.Attributes exposing (href)
import View exposing (View)


page : View msg
page =
    { title = "Homepage"
    , body =
        [ a [ href "/gap-chart" ] [ text "Gap Chart" ]
        , br [] []
        , a [ href "/lapTime-chart" ] [ text "LapTime Chart" ]
        , br [] []
        , a [ href "/lapTime-charts-by-driver" ] [ text "LapTime Charts By Driver" ]
        , br [] []
        , a [ href "/leaderboard" ] [ text "Leader Board" ]
        , br [] []
        , a [ href "/leaderboard-wec" ] [ text "Leader Board WEC" ]
        , br [] []
        , a [ href "/wec" ] [ text "Wec" ]
        ]
    }
