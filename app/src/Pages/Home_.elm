module Pages.Home_ exposing (page)

import Css exposing (block, color, display, em, fontSize, inherit)
import Data.Series as Series
import Data.Series.Wec_2024 exposing (wec_2024)
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
        , section_ "WEC 2024"
            (List.map
                (\event ->
                    link
                        { label =
                            Series.toEventSummary ( 2024, event )
                                |> Maybe.map .name
                                |> Maybe.withDefault "Unknown"
                        , path = Series.toRoutePath { season = "2024", event = event }
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


link : { label : String, path : Path } -> Html msg
link props =
    a
        [ href (Path.toString props.path)
        , css [ display block, color inherit ]
        ]
        [ text props.label ]
