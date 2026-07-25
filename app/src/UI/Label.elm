module UI.Label exposing (basicLabel)

import Html.Styled as Html exposing (Attribute, Html)
import Html.Styled.Attributes exposing (class)


{-| Outlined badge
-}
basicLabel : List (Attribute msg) -> List (Html msg) -> Html msg
basicLabel attrs children =
    Html.div (class "badge badge-outline" :: attrs) children
