module View.CarDetail exposing (elementId, view)

{-| Per-car detail, drawn in place on the event page.

It wraps `Widget.CarDetail` and is always rendered; only its contents are built
from the selected car, so it stays live-updating as the field moves.

@docs elementId, view

-}

import Html exposing (Html, div, text)
import Html.Attributes as Attributes
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Widget.CarDetail as CarDetailWidget
import Motorsport.Widget.Compare as CompareWidget
import Motorsport.Widget.Compare.CarSelector as CarSelector


view :
    { activeChart : CompareWidget.Chart
    , onToggleCar : String -> msg
    , onSelectChart : CompareWidget.Chart -> msg
    }
    -> Snapshot
    -> Maybe String
    -> Html msg
view config snapshot detailCarNumber =
    div [ Attributes.id elementId ]
        [ case detailCarNumber |> Maybe.andThen (\carNumber -> Snapshot.get carNumber snapshot) of
            Nothing ->
                carPicker config.onToggleCar snapshot

            Just focused ->
                CarDetailWidget.view
                    { onToggleCar = config.onToggleCar
                    , activeChart = config.activeChart
                    , onSelectChart = config.onSelectChart
                    }
                    snapshot
                    focused
        ]


carPicker : (String -> msg) -> Snapshot -> Html msg
carPicker onToggleCar snapshot =
    div [ Attributes.class "grid gap-y-3" ]
        (div
            [ Attributes.class "text-sm opacity-70" ]
            [ text "No cars selected. Pick a car to compare." ]
            :: (Snapshot.toClassList snapshot
                    |> List.map
                        (\( class_, _ ) ->
                            div [ Attributes.class "flex items-start gap-x-3" ]
                                [ CarSelector.classBadge class_
                                , CarSelector.carSelector onToggleCar snapshot class_ Nothing
                                ]
                        )
               )
        )


{-| The element the detail is drawn in, which the visual tests locate it by.
-}
elementId : String
elementId =
    "car-detail"
