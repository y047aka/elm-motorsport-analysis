module Motorsport.Widget.CarDetail exposing (view)

{-| Everything the race says about one car, drawn as plain inline content.

The car is the caller's selection; the rivals it is measured against are read
off the field around it, so the panel follows the race without the selection
changing.

@docs view

-}

import Html exposing (Html, div)
import Html.Attributes exposing (class)
import Motorsport.Race.Car exposing (CarNumber)
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Widget as Widget
import Motorsport.Widget.CarDetail.Stint as Stint
import Motorsport.Widget.Compare as CompareWidget
import Motorsport.Widget.SelectedCarsStrip.RivalGapSparkline as RivalGapSparkline


view :
    { onToggleCar : CarNumber -> msg
    , activeChart : CompareWidget.Chart
    , onSelectChart : CompareWidget.Chart -> msg
    }
    -> Snapshot
    -> CarAt
    -> Html msg
view config snapshot focused =
    div [ class "grid gap-y-3" ]
        [ Widget.container "Stints & pit stops"
            (Stint.view focused.metadata
                (Snapshot.lapHistory snapshot
                    |> LapHistory.get focused.metadata.carNumber
                    |> Stint.summarize
                )
            )
        , CompareWidget.viewComparison
            { onToggleCar = config.onToggleCar
            , activeChart = config.activeChart
            , onSelectChart = config.onSelectChart
            , focused = focused.metadata.carNumber
            }
            snapshot
            (comparedWith snapshot focused)
        ]


{-| The cars the comparison is drawn for: the selected one and the in-class
rivals ahead of and behind it, so the set follows the field as positions change.
At a class edge only the available rival is kept.
-}
comparedWith : Snapshot -> CarAt -> List CarNumber
comparedWith snapshot focused =
    let
        neighbors =
            RivalGapSparkline.findNeighbors (Snapshot.toList snapshot) focused
    in
    [ List.head neighbors.ahead, Just focused, List.head neighbors.behind ]
        |> List.filterMap (Maybe.map (.metadata >> .carNumber))
