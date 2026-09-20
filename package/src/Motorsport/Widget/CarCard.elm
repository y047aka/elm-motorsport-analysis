module Motorsport.Widget.CarCard exposing (view)

{-| A single car card: where the car stands, who is driving it, and how it is
running.

@docs view

-}

import Html exposing (Html, div, img, text)
import Html.Attributes exposing (alt, attribute, class, src)
import Motorsport.Analysis.Rivals as Rivals
import Motorsport.Chart.GapChart as GapChart
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Driver as Driver
import Motorsport.Gap as Gap
import Motorsport.Race.LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Status exposing (Status(..))
import Motorsport.Wec.Class as Class
import Motorsport.Widget.CarNumberBadge as CarNumberBadge
import Motorsport.Widget.SectorAndLaps as SectorAndLaps


{-| `allCars` is the full overall standings: the sparkline searches it for the
class rivals ahead of and behind the car.
-}
view : LapHistory -> List CarAt -> CarAt -> Html msg
view lapHistory allCars item =
    div
        [ class "grid gap-y-1" ]
        [ div
            [ class "px-2 grid grid-cols-[1fr_auto] gap-x-4" ]
            [ positionLabel item
            , statusBadge item.status
            ]
        , div [ class "rounded-lg border border-border bg-card" ]
            [ div
                [ class "grid gap-y-2 p-3" ]
                [ cardHeader item
                , portrait item.metadata.imageUrl item
                , summaryStats item
                , SectorAndLaps.view item
                , rivalGapSparkline lapHistory allCars item
                , LapTimeDistribution.sparkline { first = 1, last = item.standing.lapsCompleted } lapHistory item
                ]
            ]
        ]


{-| The car itself, side on, across the card at the height of the sector times
under it. These cards are 260px, so it cannot go beside the heading without
cutting the team's name, and at the width it arrives at it stands as tall as
those times and both charts together.
-}
portrait : Maybe String -> CarAt -> Html msg
portrait carImageUrl item =
    case carImageUrl of
        Just url ->
            img
                [ src url
                , alt (item.metadata.carNumber ++ " " ++ item.metadata.team)
                , class "w-full h-10 object-contain"
                ]
                []

        Nothing ->
            text ""


cardHeader : CarAt -> Html msg
cardHeader item =
    div
        [ class "grid grid-cols-[auto_1fr] items-center gap-x-2" ]
        [ CarNumberBadge.view item.metadata
        , div
            [ class "grid gap-y-0.5 min-w-0" ]
            [ div
                [ class "text-[12px] truncate" ]
                [ text item.metadata.team ]
            , div
                [ class "text-[11px] truncate" ]
                [ text (Driver.toFullName item.currentDriver) ]
            ]
        ]


summaryStats : CarAt -> Html msg
summaryStats item =
    div
        [ class "border border-border rounded-lg grid grid-cols-3" ]
        [ statCell "Laps" (text (String.fromInt item.standing.lapsCompleted))
        , statCell "Gap" (text (Gap.toString item.standing.gapToLeader))
        , statCell "Int" (text (Gap.toString item.standing.intervalToAhead))
        ]


{-| Small cell for packing a value into a single strip. Cells are separated by
a left divider (the first cell has none).
-}
statCell : String -> Html msg -> Html msg
statCell label valueHtml =
    div
        [ class "grid gap-y-px justify-items-center py-1 px-0.5 border-l border-l-border first:border-l-0" ]
        [ div
            [ class "text-[8px] uppercase tracking-[0.03em] text-muted-foreground" ]
            [ text label ]
        , div
            [ class "text-[12px] tabular-nums" ]
            [ valueHtml ]
        ]


{-| Sparkline of relative gap history against the class rivals ahead and behind.

The card's reading is relative pace: a line's slope is how it is going against
the group, and its level is where that has left it. Rising means the cumulative
time is below the reference and the relative lead is stretching; falling means
losing ground. Two lines converging or diverging is the whole point, and that
reading holds whatever the baseline is -- see
[`Rivals`](Motorsport-Analysis-Rivals) for why it is wider than the three lines
drawn.

The gaps are matched by lap number, so the rivals are assumed to be on the same
lap as this car, which in-class neighbours normally are. A lapped neighbour is
about a lap of cumulative time away at the same lap number and is clipped
outside the band as an outlier rather than flattening it.

-}
rivalGapSparkline : LapHistory -> List CarAt -> CarAt -> Html msg
rivalGapSparkline lapHistory allCars item =
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


statusBadge : Status -> Html msg
statusBadge status =
    case status of
        InPit ->
            div
                [ class "grid place-items-center w-4 h-4 rounded-full border border-border text-[9px] font-bold leading-none" ]
                [ text "P" ]

        Retired ->
            div
                [ class "py-px px-1 rounded-md bg-destructive/10 text-destructive text-[9px] font-bold tracking-wider" ]
                [ text "RET" ]

        _ ->
            text ""


positionLabel : CarAt -> Html msg
positionLabel item =
    div
        [ class "flex items-center gap-x-1 text-[10px] before:block before:content-[''] before:w-[0.2em] before:h-[1em] before:rounded-[2px] before:[background-color:var(--class-color)]"
        , attribute "style" ("--class-color: " ++ Class.toColor item.metadata.class ++ ";")
        ]
        [ text ("P" ++ String.fromInt item.standing.position)
        , div [ class "text-muted-foreground" ]
            [ text ("Class P" ++ String.fromInt item.standing.positionInClass) ]
        ]
