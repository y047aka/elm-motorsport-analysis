module UI.Label exposing (basicLabel, label)

import Html.Styled as Html exposing (Attribute, Html)
import Html.Styled.Attributes exposing (class)


{-| Basic label/badge using daisyUI badge class
-}
label : List (Attribute msg) -> List (Html msg) -> Html msg
label attrs children =
    Html.div (class "badge" :: attrs) children


{-| Outlined badge
-}
basicLabel : List (Attribute msg) -> List (Html msg) -> Html msg
basicLabel attrs children =
    Html.div (class "badge badge-outline" :: attrs) children
