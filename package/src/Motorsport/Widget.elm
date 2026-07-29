module Motorsport.Widget exposing
    ( container
    , emptyState
    )

{-|

@docs container
@docs emptyState

-}

import Css exposing (..)
import Html.Styled exposing (Html, div, h3, text)
import Html.Styled.Attributes exposing (class, css)


{-| Create a standard widget container with consistent styling
-}
container : String -> Html msg -> Html msg
container widgetTitle content =
    div
        [ class "card card-sm"
        , css [ property "background-color" "var(--widget-bg)" ]
        ]
        [ div [ class "card-body" ]
            [ h3 [ class "card-title" ] [ text widgetTitle ]
            , content
            ]
        ]


{-| Create a consistent empty state message
-}
emptyState : String -> Html msg
emptyState message =
    div
        [ css
            [ padding (px 20)
            , textAlign center
            , fontStyle italic
            , color (hsl 0 0 0.7)
            ]
        ]
        [ text message ]
