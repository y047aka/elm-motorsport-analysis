module Motorsport.Widget exposing
    ( container
    , emptyState
    )

{-|

@docs container
@docs emptyState

-}

import Html exposing (Html, div, h3, text)
import Html.Attributes exposing (class)


{-| Create a standard widget container with consistent styling
-}
container : String -> Html msg -> Html msg
container widgetTitle content =
    div
        [ class "card card-sm bg-[var(--widget-bg)]" ]
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
        [ class "p-5 text-center italic text-[hsl(0,0%,70%)]" ]
        [ text message ]
