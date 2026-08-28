module UI.Label exposing (basicLabel)

import Html exposing (Attribute, Html)
import Html.Attributes exposing (class)


{-| Outlined badge
-}
basicLabel : List (Attribute msg) -> List (Html msg) -> Html msg
basicLabel attrs children =
    Html.div
        (class "inline-flex items-center rounded-full border border-border px-2 py-0.5 text-xs font-medium text-foreground" :: attrs)
        children
