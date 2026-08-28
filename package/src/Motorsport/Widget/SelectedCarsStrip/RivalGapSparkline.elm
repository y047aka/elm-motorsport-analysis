module Motorsport.Widget.SelectedCarsStrip.RivalGapSparkline exposing (view)

{-| Sparkline of relative gap history against the class rivals ahead and behind,
shown at the bottom of each SelectedCarsStrip card.

@docs view

-}

import Dict
import Html exposing (Html, text)
import List.Extra
import Motorsport.Chart.Common exposing (Emphasis(..), LapWindow(..))
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Race.LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot exposing (CarAt)


{-| Shows the car's relationship to its rivals ahead and behind as the history of
relative gaps against a reference: the lap average of up to five neighboring cars
(the focused car plus two on each side), drawn as the dashed zero line in the
middle. The gap at each lap number is `each car's cumulative time − the group
average's cumulative time`, and three lines are displayed — the car ahead, the
focused car, and the car behind — in manufacturer colors. Only the focused car is
emphasized with a thicker, fully opaque line.

A line's slope reads as relative pace and its level as relative position: rising
means the cumulative time is below the reference (extending the relative lead),
falling means losing ground. The difference between two lines (the convergence /
divergence read) is invariant to the choice of reference, so widening the
reference to five cars does not change how closing on a rival reads. The
five-car reference relaxes the strict self-centering of a three-car reference
(the three lines summing to zero) into an approximate one, breaking the
mirror-image lock between the ahead/behind lines (the two outer cars' gaps
largely cancel, keeping the picture near zero).

The reference averages only each car's non-pit laps (no pitTime), preventing pit
stops from jolting the baseline. The vertical axis spans only the band of normal
variation with outliers (two-sided IQR) such as pit laps excluded; outliers are
clipped outside the frame. Cards missing both rivals are not drawn.

The lap sequence is a window of the most recent 20 laps, aligned across all cars
and anchored at the focused car's current lap. Both the reference and the gaps
are matched by lap number, so neighboring cars are assumed to be on the same lap
as the focused car (normally true for in-class neighbors). A lapped neighbor
differs by roughly one lap of cumulative time at the same lap number and gets
clipped outside the band as an IQR outlier.

`allCars` is the full overall standings (not the visible window); the rivals
ahead and behind are found internally as in-class neighbors in this list.

-}
view : LapHistory -> List CarAt -> CarAt -> Html msg
view lapHistory allCars item =
    let
        neighbors =
            findNeighbors allCars item

        currentLap =
            item.standing.lapsCompleted

        aheadLines =
            neighbors.ahead |> List.map (GapChart.carLine lapHistory (Recent currentLap) Related)

        behindLines =
            neighbors.behind |> List.map (GapChart.carLine lapHistory (Recent currentLap) Related)

        focusedLine =
            GapChart.carLine lapHistory (Recent currentLap) Focused item

        -- Display the nearest rival on each side plus the focused car
        -- (ahead → focused → behind); missing neighbors are dropped.
        cars =
            List.filterMap identity [ List.head aheadLines, Just focusedLine, List.head behindLines ]

        -- Render guard: a card missing both rivals has no gap comparison to draw.
        rivalLines =
            List.filterMap identity [ List.head aheadLines, List.head behindLines ]

        -- The reference population is up to five cars (two on each side plus
        -- the focused car), kept separate from the three displayed lines.
        referenceCars =
            aheadLines ++ focusedLine :: behindLines

        -- Lap number → non-pit average elapsed of the reference group. Used as a render guard.
        referenceByLap =
            GapChart.groupReferenceByLap referenceCars

        -- Blank carNumber to omit the end-of-line label on these narrow cards
        -- (renderLine skips empty strings).
        carsWithGaps =
            GapChart.plotGaps
                { reference = referenceCars
                , display = cars |> List.map (\car -> { car | carNumber = "" })
                }

        focusedLapNumbers =
            focusedLine.laps |> List.map (.lap >> toFloat)
    in
    case ( focusedLapNumbers, rivalLines, Dict.isEmpty referenceByLap ) of
        ( _ :: _ :: _, _ :: _, False ) ->
            GapChart.gapSparkline GapChart.rivalStrip
                ( List.minimum focusedLapNumbers |> Maybe.withDefault 0
                , List.maximum focusedLapNumbers |> Maybe.withDefault 1
                )
                carsWithGaps

        _ ->
            text ""


{-| Cars adjacent to the focused car in same-class order, held nearest-first with
up to two on each side (`ahead = [A1, A2]`, `behind = [B1, B2]`). The display
uses only the nearest one on each side (`List.head`); the reference population
uses all of them. Fewer cars are available at the front/back or class edges.
-}
type alias Neighbors =
    { ahead : List CarAt
    , behind : List CarAt
    }


{-| Pick up to two cars on each side of `item` in same-class order. Filtering the
overall standings by class preserves order, so the result is the in-class order
as-is. At class edges only the available cars are returned (out-of-range indices
are dropped).
-}
findNeighbors : List CarAt -> CarAt -> Neighbors
findNeighbors allCars item =
    let
        classmates =
            allCars |> List.filter (\e -> e.metadata.class == item.metadata.class)
    in
    case List.Extra.findIndex (\e -> e.metadata.carNumber == item.metadata.carNumber) classmates of
        Just i ->
            { ahead = [ 1, 2 ] |> List.filterMap (\d -> List.Extra.getAt (i - d) classmates)
            , behind = [ 1, 2 ] |> List.filterMap (\d -> List.Extra.getAt (i + d) classmates)
            }

        Nothing ->
            { ahead = [], behind = [] }
