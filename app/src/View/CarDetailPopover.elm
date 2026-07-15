module View.CarDetailPopover exposing (popoverId, view)

{-| Car detail popover.

A glassmorphism popover that wraps `Compare.viewComparison`. It is always
rendered so a row click can open it via `popovertarget`; only its contents are
built from the currently selected cars (and stay live-updating while open).
`popover="auto"` gives light-dismiss (outside click / Esc).

The element id is exposed as [`popoverId`](#popoverId) so callers can wire it up
as the `popovertarget` of the trigger.

@docs popoverId, view

-}

import Css
import Html.Styled as Html exposing (Html, button, text)
import Html.Styled.Attributes as Attributes exposing (attribute, css)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Clock as Clock
import Motorsport.Standings as Standings
import Motorsport.Widget.Compare as CompareWidget


popoverId : String
popoverId =
    "car-detail-popover"


view :
    { season : Int
    , analysis : Analysis
    , clock : Clock.Model
    , activeChart : CompareWidget.Chart
    , onToggleCar : String -> msg
    , onSelectChart : CompareWidget.Chart -> msg
    }
    -> Standings.Standings
    -> List String
    -> Html msg
view config standings detailCarNumbers =
    Html.node "div"
        [ Attributes.id popoverId
        , attribute "popover" "auto"

        -- Style with daisyUI's modal-box. modal-box sets no display, so the UA's
        -- "a closed popover is display:none" applies as-is.
        , Attributes.class "modal-box"
        , css
            [ -- Tailwind preflight cancels the UA's margin:auto, so set it explicitly to center.
              Css.property "margin" "auto"
            , Css.property "max-width" "min(90vw, 1200px)"
            , Css.property "padding" "1rem"

            -- Glassmorphism: translucent background + backdrop blur + border.
            -- Colors are managed by app-side DaisyUI theme tokens (--glass-*).
            , Css.property "background-color" "var(--glass-bg)"
            , Css.property "backdrop-filter" "blur(16px)"
            , Css.property "-webkit-backdrop-filter" "blur(16px)"
            , Css.property "border" "1px solid var(--glass-border)"
            , Css.property "box-shadow" "0 0 80px var(--glass-shadow)"

            -- .modal-box collapses opacity/scale assuming it opens inside a .modal,
            -- so restore them in the popover's open state.
            , Css.pseudoClass "popover-open"
                [ Css.property "opacity" "1"
                , Css.property "scale" "1"
                ]
            , Css.pseudoElement "backdrop"
                [ Css.property "background-color" "var(--glass-backdrop)" ]
            ]
        ]
        [ button
            [ attribute "popovertarget" popoverId
            , attribute "popovertargetaction" "hide"
            , Attributes.class "btn btn-sm btn-circle btn-ghost absolute right-2 top-2"
            ]
            [ text "✕" ]
        , case detailCarNumbers of
            [] ->
                -- Deselecting the last car must not leave an empty modal:
                -- keep the close button above and explain how to recover.
                Html.div
                    [ Attributes.class "py-8 text-center text-sm opacity-70" ]
                    [ text "No cars selected. Pick a car from the standings to compare." ]

            _ ->
                CompareWidget.viewComparison
                    { season = config.season
                    , analysis = config.analysis
                    , clock = config.clock
                    , onToggleCar = config.onToggleCar
                    , activeChart = config.activeChart
                    , onSelectChart = config.onSelectChart
                    }
                    standings
                    detailCarNumbers
        ]
