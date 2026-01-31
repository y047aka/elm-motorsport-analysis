module UI.Button exposing
    ( button
    , labeledButton
    )

import Html.Styled as Html exposing (Attribute, Html)
import Html.Styled.Attributes exposing (class)


{-| Basic button using daisyUI btn class
-}
button : List (Attribute msg) -> List (Html msg) -> Html msg
button attrs children =
    Html.button (class "btn" :: attrs) children


{-| Labeled button using daisyUI join component
-}
labeledButton : List (Attribute msg) -> List (Html msg) -> Html msg
labeledButton attrs children =
    Html.div (class "join" :: attrs) children
