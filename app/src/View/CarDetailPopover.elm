module View.CarDetailPopover exposing (popoverId, view)

{-| Car detail popover.

A popover that wraps `Compare.viewComparison`. It is always
rendered so a row click can open it via `popovertarget`; only its contents are
built from the currently selected cars (and stay live-updating while open).
`popover="auto"` gives light-dismiss (outside click / Esc).

The element id is exposed as [`popoverId`](#popoverId) so callers can wire it up
as the `popovertarget` of the trigger.

@docs popoverId, view

-}

import Html exposing (Html, button, div, text)
import Html.Attributes as Attributes exposing (attribute)
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

        -- Tailwind preflight cancels the UA's margin:auto, so set it explicitly to center.
        -- The popover has no containing block to size against but the viewport,
        -- so its width is set explicitly rather than left to shrink to content.
        , Attributes.class "m-auto w-11/12 max-w-[min(90vw,1200px)] p-4 rounded-xl overflow-y-auto max-h-screen"
        , Attributes.class "bg-popover text-popover-foreground border border-border shadow-lg"

        -- A closed popover is display:none by the UA, but its entrance
        -- transition still needs an explicit closed state to animate from.
        , Attributes.class "opacity-0 scale-95 transition-[opacity,scale] duration-200 [&:popover-open]:opacity-100 [&:popover-open]:scale-100"
        , Attributes.class "backdrop:bg-black/50"
        ]
        [ button
            [ attribute "popovertarget" popoverId
            , attribute "popovertargetaction" "hide"
            , Attributes.class "inline-flex items-center justify-center size-8 rounded-full text-sm cursor-pointer transition-colors hover:bg-accent hover:text-accent-foreground absolute right-2 top-2"
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
                CompareWidget.viewComparison
                    { onToggleCar = config.onToggleCar
                    , activeChart = config.activeChart
                    , onSelectChart = config.onSelectChart
                    }
                    snapshot
                    detailCarNumbers
        ]
