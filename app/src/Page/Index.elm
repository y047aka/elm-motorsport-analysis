module Page.Index exposing (view)

{-| The top page. It is stateless, so it exposes only a `view`.

@docs view

-}

import Css exposing (block, color, display, em, fontSize, inherit)
import Data.Series.Wec_2024 exposing (wec_2024)
import Data.Series.Wec_2025 exposing (wec_2025)
import Data.Series.Wec_2026 exposing (wec_2026)
import Html.Styled exposing (Html, div, h2, section, text)
import Html.Styled.Attributes exposing (attribute, css)
import Route exposing (Route)
import View exposing (View)


view : View msg
view =
    { title = "Race Analysis"
    , body =
        [ div [ attribute "data-theme" "forest" ]
            [ section_ "WEC 2026"
                (List.map
                    (\eventSummary ->
                        link
                            { label = eventSummary.name
                            , route = Route.WecEvent { season = "2026", event = eventSummary.id }
                            }
                    )
                    wec_2026
                )
            , section_ "WEC 2025"
                (List.map
                    (\eventSummary ->
                        link
                            { label = eventSummary.name
                            , route = Route.WecEvent { season = "2025", event = eventSummary.id }
                            }
                    )
                    wec_2025
                )
            , section_ "WEC 2024"
                (List.map
                    (\eventSummary ->
                        link
                            { label = eventSummary.name
                            , route = Route.WecEvent { season = "2024", event = eventSummary.id }
                            }
                    )
                    wec_2024
                )
            ]
        ]
    }


section_ : String -> List (Html msg) -> Html msg
section_ title children =
    section []
        (h2 [ css [ fontSize (em 1) ] ] [ text title ]
            :: children
        )


link : { label : String, route : Route } -> Html msg
link props =
    Html.Styled.a
        [ Route.href props.route
        , css [ display block, color inherit ]
        ]
        [ text props.label ]
