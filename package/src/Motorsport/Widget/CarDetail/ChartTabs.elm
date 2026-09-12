module Motorsport.Widget.CarDetail.ChartTabs exposing (chartTabs)

{-| The bar that switches the chart under it, and that chart.

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

The bar and the chart are drawn plain: what they sit in is the section they
belong to, which holds the rest of what the chart is about.

-}
chartTabs : (tab -> msg) -> tab -> List ( tab, String, () -> Html msg ) -> Html msg
chartTabs onSelect active tabs =
    div
        [ class "grid gap-y-1" ]
        [ div [ class "grid grid-flow-col auto-cols-[minmax(0,1fr)]" ]
            (List.map (\( chart, label, _ ) -> chartTabButton onSelect chart label (chart == active)) tabs)
        , tabs
            |> List.Extra.find (\( chart, _, _ ) -> chart == active)
            |> Maybe.map (\( _, _, content ) -> content ())
            |> Maybe.withDefault (text "")
        ]


{-| Tab button for `chartTabs`, the Event page's joined button group at the size
a panel column has room for: three of these share the width, so a label that
wrapped to two lines took the bar to twice the height of the buttons in it.
-}
chartTabButton : (tab -> msg) -> tab -> String -> Bool -> Html msg
chartTabButton onSelect chart label isActive =
    button
        [ onClick (onSelect chart)
        , class
            ("inline-flex h-7 items-center justify-center border border-border px-2 text-xs font-medium whitespace-nowrap cursor-pointer transition-colors -ml-px first:ml-0 first:rounded-l-md last:rounded-r-md"
                ++ (if isActive then
                        " bg-primary text-primary-foreground border-primary"

                    else
                        " bg-accent/40 text-foreground hover:bg-accent/70"
                   )
            )
        ]
        [ text label ]
