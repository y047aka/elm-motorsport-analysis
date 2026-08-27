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

import Html exposing (Html, button, div, text)
import Html.Attributes as Attributes exposing (attribute)
import Html.Styled
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Widget.Compare as CompareWidget


popoverId : String
popoverId =
    "car-detail-popover"


view :
    { activeChart : CompareWidget.Chart
    , onToggleCar : String -> msg
    , onSelectChart : CompareWidget.Chart -> msg
    }
    -> Snapshot
    -> List String
    -> Html msg
view config snapshot detailCarNumbers =
    Html.node "div"
        [ Attributes.id popoverId
        , attribute "popover" "auto"

        -- Style with daisyUI's modal-box. modal-box sets no display, so the UA's
        -- "a closed popover is display:none" applies as-is.
        , Attributes.class "modal-box"

        -- Tailwind preflight cancels the UA's margin:auto, so set it explicitly to center.
        , Attributes.class "m-auto max-w-[min(90vw,1200px)] p-4"

        -- Glassmorphism: translucent background + backdrop blur + border.
        -- Colors are managed by app-side DaisyUI theme tokens (--glass-*).
        , Attributes.class "bg-[var(--glass-bg)] backdrop-blur-lg border border-[var(--glass-border)] shadow-[0_0_80px_var(--glass-shadow)]"

        -- .modal-box collapses opacity/scale assuming it opens inside a .modal,
        -- so restore them in the popover's open state.
        , Attributes.class "[&:popover-open]:opacity-100 [&:popover-open]:scale-100"
        , Attributes.class "backdrop:bg-[var(--glass-backdrop)]"
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
                div
                    [ Attributes.class "py-8 text-center text-sm opacity-70" ]
                    [ text "No cars selected. Pick a car from the standings to compare." ]

            _ ->
                Html.Styled.toUnstyled
                    (CompareWidget.viewComparison
                        { onToggleCar = config.onToggleCar
                        , activeChart = config.activeChart
                        , onSelectChart = config.onSelectChart
                        }
                        snapshot
                        detailCarNumbers
                    )
        ]
