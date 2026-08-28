module Motorsport.Widget.Compare.ChartTabs exposing (chartTabs)

{-| Panel that switches the lower chart via tabs.

@docs chartTabs

-}

import Html exposing (Html, button, div, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import List.Extra


{-| Switches charts via tabs to fit them into a single chart's footprint. The tab
mechanism is the same joined button group as the Event page's mode selector:
clicking fires `onSelect` to switch `active` (the caller holds the state). Each
content is passed as a lazy thunk so inactive charts are not rendered.
-}
chartTabs : (tab -> msg) -> tab -> List ( tab, String, () -> Html msg ) -> Html msg
chartTabs onSelect active tabs =
    div
        [ class "bg-[var(--glass-panel-dark-bg)] border border-[var(--glass-panel-dark-border)] rounded-lg p-2 grid" ]
        [ div [ class "inline-flex" ]
            (List.map (\( chart, label, _ ) -> chartTabButton onSelect chart label (chart == active)) tabs)
        , tabs
            |> List.Extra.find (\( chart, _, _ ) -> chart == active)
            |> Maybe.map (\( _, _, content ) -> content ())
            |> Maybe.withDefault (text "")
        ]


{-| Tab button for `chartTabs`, matched to the look of the Event page's `joinButton`.
-}
chartTabButton : (tab -> msg) -> tab -> String -> Bool -> Html msg
chartTabButton onSelect chart label isActive =
    button
        [ onClick (onSelect chart)
        , class
            ("inline-flex h-8 items-center justify-center border border-border px-3 text-sm font-medium cursor-pointer transition-colors -ml-px first:ml-0 first:rounded-l-md last:rounded-r-md"
                ++ (if isActive then
                        " bg-primary text-primary-foreground border-primary"

                    else
                        " bg-accent/40 text-foreground hover:bg-accent/70"
                   )
            )
        ]
        [ text label ]
