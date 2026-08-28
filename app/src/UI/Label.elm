module UI.Label exposing (basicLabel)

import Html exposing (Attribute, Html)
import Html.Attributes exposing (class)


{-| Outlined badge
-}
basicLabel : List (Attribute msg) -> List (Html msg) -> Html msg
basicLabel attrs children =
    Html.div (class "badge badge-outline" :: attrs) children
