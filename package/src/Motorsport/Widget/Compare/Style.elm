module Motorsport.Widget.Compare.Style exposing (glassPanel, glassPanelDark, panelLabel)

{-| Glassmorphism-style panel and heading styles shared across the Compare widget.

@docs glassPanel, glassPanelDark, panelLabel

-}

import Css exposing (num, opacity, property)
import Html.Styled exposing (Html, div, text)
import Html.Styled.Attributes exposing (css)


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


{-| Dark variant of `glassPanel`. Where the default lifts with a white tint, this
sinks one step with a faint black tint. Used as the background for line charts to
improve line visibility. Fill is managed by the app-side DaisyUI theme token
(`--glass-panel-dark-bg`).
-}
glassPanelDark : Css.Style
glassPanelDark =
    Css.batch
        [ property "background-color" "var(--glass-panel-dark-bg)"
        , property "border" "1px solid var(--glass-panel-dark-border)"
        , property "border-radius" "8px"
        ]


{-| Shared panel-heading style: small, uppercase, low opacity.
-}
panelLabel : String -> Html msg
panelLabel label =
    div
        [ css
            [ property "font-size" "9px"
            , property "text-transform" "uppercase"
            , property "letter-spacing" "0.05em"
            , opacity (num 0.5)
            ]
        ]
        [ text label ]
