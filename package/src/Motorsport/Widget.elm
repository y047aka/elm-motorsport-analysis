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
        [ class "rounded-lg border border-border bg-card" ]
        [ div [ class "flex flex-col gap-2 p-3" ]
            [ h3 [ class "font-semibold text-sm" ] [ text widgetTitle ]
            , content
            ]
        ]


{-| Create a consistent empty state message
-}
emptyState : String -> Html msg
emptyState message =
    div
        [ class "p-5 text-center italic text-muted-foreground" ]
        [ text message ]
