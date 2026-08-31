module View.CarDetailPopover exposing (elementId, view)

{-| Per-car detail, drawn in place on the event page.

It wraps `Compare.viewComparison` and is always rendered; only its contents are
built from the currently selected cars, so it stays live-updating.

@docs elementId, view

-}

import Html exposing (Html, div, text)
import Html.Attributes as Attributes
import Motorsport.Race.Snapshot exposing (Snapshot)
import Motorsport.Widget.Compare as CompareWidget


view :
    { activeChart : CompareWidget.Chart
    , onToggleCar : String -> msg
    , onSelectChart : CompareWidget.Chart -> msg
    }
    -> Snapshot
    -> List String
    -> Html msg
view config snapshot detailCarNumbers =
    div [ Attributes.id elementId ]
        [ case detailCarNumbers of
            [] ->
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


{-| The element the detail is drawn in, which the visual tests locate it by.
-}
elementId : String
elementId =
    "car-detail"
