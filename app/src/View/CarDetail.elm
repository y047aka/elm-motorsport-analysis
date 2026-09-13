module View.CarDetail exposing (elementId, view)

{-| Per-car detail, drawn in place on the event page.

It wraps `Widget.CarDetail` and is always rendered; only its contents are built
from the car it is given, so it stays live-updating as the field moves.

@docs elementId, view

-}

import Html exposing (Html, div, text)
import Html.Attributes as Attributes
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Snapshot exposing (CarAt, Snapshot)
import Motorsport.Widget.CarDetail as CarDetailWidget


view :
    { activeChart : CarDetailWidget.Chart
    , onSelectChart : CarDetailWidget.Chart -> msg
    , lapHistoryOpen : Bool
    , onToggleLapHistory : msg
    }
    -> List Car
    -> Snapshot
    -> Maybe CarAt
    -> Html msg
view config cars snapshot focusedCar =
    div [ Attributes.id elementId ]
        [ case focusedCar of
            Nothing ->
                -- Only before a car of the field has turned a lap, which is not
                -- a moment the page is read at.
                text ""

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


{-| The element the detail is drawn in, which the visual tests locate it by.
-}
elementId : String
elementId =
    "car-detail"
