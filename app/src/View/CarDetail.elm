module View.CarDetail exposing (elementId, view)

{-| Per-car detail, drawn in place on the event page.

It wraps `Compare.viewComparison` and is always rendered; only its contents are
built from the selected car and its in-class rivals ahead of and behind it, so
it stays live-updating as the field moves.

@docs elementId, view

-}

import Html exposing (Html, div, text)
import Html.Attributes as Attributes
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Widget.Compare as CompareWidget
import Motorsport.Widget.Compare.CarSelector as CarSelector
import Motorsport.Widget.SelectedCarsStrip.RivalGapSparkline as RivalGapSparkline


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
        [ case detailCarNumber of
            Nothing ->
                div [ Attributes.class "grid gap-y-3" ]
                    (div
                        [ Attributes.class "text-sm opacity-70" ]
                        [ text "No cars selected. Pick a car to compare." ]
                        :: (Snapshot.toClassList snapshot
                                |> List.map
                                    (\( class_, _ ) ->
                                        div [ Attributes.class "flex items-start gap-x-3" ]
                                            [ CarSelector.classBadge class_
                                            , CarSelector.carSelector config.onToggleCar snapshot class_ Nothing
                                            ]
                                    )
                           )
                    )

            Just selected ->
                CompareWidget.viewComparison
                    { onToggleCar = config.onToggleCar
                    , activeChart = config.activeChart
                    , onSelectChart = config.onSelectChart
                    , focused = selected
                    }
                    snapshot
                    (comparisonNumbers snapshot selected)
        ]


{-| The cars the comparison is drawn for: the selected one and its in-class
rivals ahead of and behind it, so the set follows the field as positions
change. At a class edge only the available rival is kept.

Same extraction as the strip's rival sparkline; only the nearest on each side
is shown there too.

-}
comparisonNumbers : Snapshot -> String -> List String
comparisonNumbers snapshot selected =
    case Snapshot.get selected snapshot of
        Nothing ->
            []

        Just focused ->
            let
                neighbors =
                    RivalGapSparkline.findNeighbors (Snapshot.toList snapshot) focused
            in
            [ List.head neighbors.ahead, Just focused, List.head neighbors.behind ]
                |> List.filterMap (Maybe.map (.metadata >> .carNumber))


{-| The element the detail is drawn in, which the visual tests locate it by.
-}
elementId : String
elementId =
    "car-detail"
