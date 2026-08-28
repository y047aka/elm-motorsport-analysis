module Motorsport.Widget.Compare.ChartTabs exposing (chartTabs)

{-| Panel that switches the lower chart via tabs.

@docs chartTabs

-}

import Html exposing (Html, button, div, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import List.Extra


{-| Switches charts via tabs to fit them into a single chart's footprint. The tab
mechanism is the same `join` button group as the Event page's mode selector:
clicking fires `onSelect` to switch `active` (the caller holds the state). Each
content is passed as a lazy thunk so inactive charts are not rendered.
-}
chartTabs : (tab -> msg) -> tab -> List ( tab, String, () -> Html msg ) -> Html msg
chartTabs onSelect active tabs =
    div
        [ class "bg-[var(--glass-panel-dark-bg)] border border-[var(--glass-panel-dark-border)] rounded-lg p-2 grid" ]
        [ div [ class "join" ]
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
            ("join-item btn btn-sm btn-soft"
                ++ (if isActive then
                        " btn-active"

                    else
                        ""
                   )
            )
        ]
        [ text label ]
