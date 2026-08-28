module UI.Button exposing
    ( button
    , labeledButton
    )

import Html exposing (Attribute, Html)
import Html.Attributes exposing (class)


{-| Basic button.
-}
button : List (Attribute msg) -> List (Html msg) -> Html msg
button attrs children =
    Html.button
        (class "inline-flex items-center justify-center gap-1.5 rounded-md bg-card px-4 h-10 text-sm font-semibold text-foreground cursor-pointer transition-colors hover:bg-accent hover:text-accent-foreground" :: attrs)
        children


{-| Groups buttons in a row.
-}
labeledButton : List (Attribute msg) -> List (Html msg) -> Html msg
labeledButton attrs children =
    Html.div (class "inline-flex items-center gap-1" :: attrs) children
