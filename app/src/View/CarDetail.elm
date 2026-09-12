module View.CarDetail exposing (elementId, view)

{-| Per-car detail, drawn in place on the event page.

It wraps `Widget.CarDetail` and is always rendered; only its contents are built
from the selected car, so it stays live-updating as the field moves.

@docs elementId, view

-}

import Html exposing (Html, div, text)
import Html.Attributes as Attributes
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Widget.CarDetail as CarDetailWidget


view :
    { activeChart : CarDetailWidget.Chart
    , onSelectChart : CarDetailWidget.Chart -> msg
    , lapHistoryOpen : Bool
    , onToggleLapHistory : msg
    }
    -> List Car
    -> Snapshot
    -> Maybe String
    -> Html msg
view config cars snapshot detailCarNumber =
    div [ Attributes.id elementId ]
        [ case detailCarNumber |> Maybe.andThen (\carNumber -> Snapshot.get carNumber snapshot) of
            Nothing ->
                nothingSelected

            Just focused ->
                CarDetailWidget.view
                    { activeChart = config.activeChart
                    , onSelectChart = config.onSelectChart
                    , lapHistoryOpen = config.lapHistoryOpen
                    , onToggleLapHistory = config.onToggleLapHistory
                    }
                    cars
                    snapshot
                    focused
        ]


{-| The panel with nothing to show, which is the standings' cue rather than its
own: picking a car is that list's job.
-}
nothingSelected : Html msg
nothingSelected =
    div [ Attributes.class "text-sm opacity-70" ]
        [ text "No car selected. Pick one from the standings on the left." ]


{-| The element the detail is drawn in, which the visual tests locate it by.
-}
elementId : String
elementId =
    "car-detail"
