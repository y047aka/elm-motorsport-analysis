module Motorsport.Widget.CarDetail.ChartTabs exposing (chartTabs, segmentedControl)

{-| The bar that switches the chart under it, and that chart. The bar carries
the tabs at one end and whatever else the caller puts at the other, both made of
the same joined button group.

@docs chartTabs, segmentedControl

-}

import Html exposing (Html, button, div, text)
import Html.Attributes exposing (class)
import Html.Events exposing (onClick)
import List.Extra


{-| The tab mechanism is the same joined button group as the Event page's mode
selector: clicking fires `onSelect` to switch `active` (the caller holds the
state). Each content is passed as a lazy thunk so inactive charts are not
rendered.

`controls` sits at the other end of the bar, for what the chart showing is drawn
with rather than which chart it is -- the stretch of the race, which all of them
share.

The bar and the chart are drawn plain: what they sit in is the section they
belong to, which holds the rest of what the chart is about.

-}
chartTabs : (tab -> msg) -> tab -> Html msg -> List ( tab, String, () -> Html msg ) -> Html msg
chartTabs onSelect active controls tabs =
    div
        [ class "grid gap-y-1" ]
        [ div [ class "flex items-center justify-between gap-x-2" ]
            [ segmentedControl onSelect active (List.map (\( chart, label, _ ) -> ( chart, label )) tabs)
            , controls
            ]
        , tabs
            |> List.Extra.find (\( chart, _, _ ) -> chart == active)
            |> Maybe.map (\( _, _, content ) -> content ())
            |> Maybe.withDefault (text "")
        ]


{-| One joined button group, each button as wide as its own label: two of these
share the bar, and stretching either to the width it sits in would leave the
labels marooned in the middle of buttons that say nothing more for the room.
-}
segmentedControl : (option -> msg) -> option -> List ( option, String ) -> Html msg
segmentedControl onSelect active options =
    div [ class "flex shrink-0" ]
        (List.map (\( value, label ) -> segmentButton onSelect value label (value == active)) options)


{-| One button of a group, the Event page's joined button group at the size a
panel column has room for.
-}
segmentButton : (option -> msg) -> option -> String -> Bool -> Html msg
segmentButton onSelect value label isActive =
    button
        [ onClick (onSelect value)
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
