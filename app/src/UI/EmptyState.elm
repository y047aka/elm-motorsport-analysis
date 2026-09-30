module UI.EmptyState exposing (view)

{-| The one way these panels say there is nothing to draw where a reader came
for something.

@docs view

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)


view : String -> Html msg
view message =
    div [ class "p-5 text-center italic text-muted-foreground" ]
        [ text message ]
