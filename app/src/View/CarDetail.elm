module View.CarDetail exposing (elementId, view)

{-| Per-car detail, drawn in place on the event page.

It wraps `Compare.viewComparison` and is always rendered; only its contents are
built from the currently selected cars, so it stays live-updating.

@docs elementId, view

-}

import Html exposing (Html, div, text)
import Html.Attributes as Attributes
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Widget.Compare as CompareWidget
import Motorsport.Widget.Compare.CarSelector as CarSelector


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
                div [ Attributes.class "grid gap-y-3" ]
                    (div
                        [ Attributes.class "text-sm opacity-70" ]
                        [ text "No cars selected. Pick a car to compare." ]
                        :: (Snapshot.toClassList snapshot
                                |> List.map
                                    (\( class_, _ ) ->
                                        div [ Attributes.class "flex items-start gap-x-3" ]
                                            [ CarSelector.classBadge class_
                                            , CarSelector.carSelector config.onToggleCar snapshot class_ []
                                            ]
                                    )
                           )
                    )

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
