module Motorsport.Widget.CarCard exposing (view)

{-| A single car card for SelectedCarsStrip: where the car stands, who is
driving it, and how it is running.

@docs view

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (attribute, class)
import Motorsport.Chart.LapTimeDistribution as LapTimeDistribution
import Motorsport.Driver as Driver
import Motorsport.Gap as Gap
import Motorsport.Race.LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Status exposing (Status(..))
import Motorsport.Wec.Class as Class
import Motorsport.Widget.CarNumberBadge as CarNumberBadge
import Motorsport.Widget.Distribution as Distribution
import Motorsport.Widget.SectorAndLaps as SectorAndLaps
import Motorsport.Widget.SelectedCarsStrip.RivalGapSparkline as RivalGapSparkline


{-| `allCars` is the full overall standings, not just the visible window —
the sparkline searches it for the class rivals ahead of and behind the car.
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
                , summaryStats item
                , SectorAndLaps.view item
                , RivalGapSparkline.view lapHistory allCars item
                , lapTimeDistribution lapHistory item
                ]
            ]
        ]


{-| The car's own laps, on a scale of their own: the cards beside it are the
overall order rather than one class, and two classes on one lap-time axis
flatten both.
-}
lapTimeDistribution : LapHistory -> CarAt -> Html msg
lapTimeDistribution lapHistory item =
    let
        series =
            Distribution.seriesOf lapHistory ( 1, item.standing.lapsCompleted ) item
    in
    case Distribution.scaleOf [ series ] of
        Just { domain, maxDensity } ->
            LapTimeDistribution.view
                { width = 220, height = 50, domain = domain, maxDensity = maxDensity }
                [ series ]

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
                [ class "text-[11px] opacity-70 truncate" ]
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
            [ class "text-[8px] uppercase tracking-[0.03em] opacity-50" ]
            [ text label ]
        , div
            [ class "text-[12px] tabular-nums" ]
            [ valueHtml ]
        ]


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
        , div [ class "opacity-60" ]
            [ text ("Class P" ++ String.fromInt item.standing.positionInClass) ]
        ]
