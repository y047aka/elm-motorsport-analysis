module Motorsport.Widget.SelectedCarsStrip.RivalGapSparkline exposing (view)

{-| Sparkline of relative gap history against the class rivals ahead and behind,
shown at the bottom of each car card.

@docs view

-}

import Html exposing (Html)
import Motorsport.Analysis.Rivals as Rivals
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Race.LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot exposing (CarAt)


{-| The card's reading is relative pace: a line's slope is how it is going
against the group, and its level is where that has left it. Rising means the
cumulative time is below the reference and the relative lead is stretching;
falling means losing ground. Two lines converging or diverging is the whole
point, and that reading holds whatever the baseline is -- see
[`Rivals`](Motorsport-Analysis-Rivals) for why it is wider than the three lines
drawn.

The gaps are matched by lap number, so the rivals are assumed to be on the same
lap as this car, which in-class neighbours normally are. A lapped neighbour is
about a lap of cumulative time away at the same lap number and is clipped
outside the band as an outlier rather than flattening it.

`allCars` is the whole running order rather than the cards on screen: the rivals
are the ones on the road, not the ones the strip happens to show.

-}
view : LapHistory -> List CarAt -> CarAt -> Html msg
view lapHistory allCars item =
    let
        currentLap =
            item.standing.lapsCompleted
    in
    GapChart.gapSparkline { first = currentLap - recentLapCount, last = currentLap }
        lapHistory
        (Rivals.around allCars item)


{-| How many laps back the card reaches. A card is a thumbnail of the last
stretch of the race, not of the race.
-}
recentLapCount : Int
recentLapCount =
    20
