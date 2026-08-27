module Motorsport.Widget.Compare.Style exposing (panelLabel)

{-| Heading style shared across the Compare widget.

@docs panelLabel

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)


{-| Shared panel-heading style: small, uppercase, low opacity.
-}
panelLabel : String -> Html msg
panelLabel label =
    div [ class "text-[9px] uppercase tracking-wider opacity-50" ] [ text label ]
