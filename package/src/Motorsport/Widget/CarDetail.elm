module Motorsport.Widget.CarDetail exposing (view)

{-| Everything the race says about one car, drawn as plain inline content.

The car is the caller's selection; the rivals it is measured against are read
off the field around it, so the panel follows the race without the selection
changing.

@docs view

-}

import Html exposing (Html, div)
import Html.Attributes exposing (class)
import List.Extra
import Motorsport.Gap exposing (Gap)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Race.LapHistory as LapHistory
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Widget as Widget
import Motorsport.Widget.CarDetail.Header as Header
import Motorsport.Widget.CarDetail.LiveTiming as LiveTiming
import Motorsport.Widget.CarDetail.Stint as Stint
import Motorsport.Widget.Compare as CompareWidget
import Motorsport.Widget.SelectedCarsStrip.RivalGapSparkline as RivalGapSparkline


view :
    { onToggleCar : CarNumber -> msg
    , activeChart : CompareWidget.Chart
    , onSelectChart : CompareWidget.Chart -> msg
    }
    -> List Car
    -> Snapshot
    -> CarAt
    -> Html msg
view config cars snapshot focused =
    div [ class "grid gap-y-3" ]
        [ Header.view
            { startPosition = startPositionOf cars focused
            , behind = behind snapshot focused
            }
            focused
        , Widget.container "Live timing"
            (LiveTiming.view (Snapshot.bestTimes snapshot) focused)
        , Widget.container "Stints & pit stops"
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


startPositionOf : List Car -> CarAt -> Maybe Int
startPositionOf cars focused =
    cars
        |> List.Extra.find (\car -> car.metadata.carNumber == focused.metadata.carNumber)
        |> Maybe.map .startPosition


{-| How far the next car in the running order is behind this one, which is the
gap that car is given to the one ahead of it.
-}
behind : Snapshot -> CarAt -> Maybe Gap
behind snapshot focused =
    Snapshot.toList snapshot
        |> List.Extra.dropWhile (\item -> item.metadata.carNumber /= focused.metadata.carNumber)
        |> List.drop 1
        |> List.head
        |> Maybe.map (.standing >> .intervalToAhead)


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
