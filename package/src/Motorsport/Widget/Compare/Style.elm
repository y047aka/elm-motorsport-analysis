module Motorsport.Widget.Compare.Style exposing (glassPanel, panelLabel)

{-| Glassmorphism-style panel and heading styles shared across the Compare widget.

@docs glassPanel, panelLabel

-}

import Css exposing (property)
import Html exposing (Html, div, text)
import Html.Attributes exposing (class)


{-| Translucent panel that blends with the modal's glassmorphism. It sits on top
of the dialog surface and lifts one step with a faint white tint. Fill and border
colors are managed by app-side DaisyUI theme tokens (`--glass-panel-bg` /
`--glass-panel-border`).
-}
glassPanel : Css.Style
glassPanel =
    Css.batch
        [ property "background-color" "var(--glass-panel-bg)"
        , property "border" "1px solid var(--glass-panel-border)"
        , property "border-radius" "8px"
        ]


{-| Shared panel-heading style: small, uppercase, low opacity.
-}
panelLabel : String -> Html msg
panelLabel label =
    div [ class "text-[9px] uppercase tracking-wider opacity-50" ] [ text label ]
