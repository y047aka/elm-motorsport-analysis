module Motorsport.Widget.SelectedCarsStrip.CarCard exposing (view)

{-| A single car card for SelectedCarsStrip: a header row of position, gap, and
status, above the driver name, sector performance, and rival gap sparkline.

@docs view

-}

import Html.Styled exposing (Html, div, text)
import Html.Styled.Attributes exposing (attribute, class)
import Motorsport.Driver as Driver
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Race.LapHistory exposing (LapHistory)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Status exposing (Status(..))
import Motorsport.Wec.Class as Class
import Motorsport.Widget.CarNumberBadge as CarNumberBadge
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
            [ class "px-2 grid grid-cols-[auto_1fr_auto] gap-x-4" ]
            [ positionLabel item
            , gapsRow item
            , statusBadge item.status
            ]
        , div [ class "card bg-base-200" ]
            [ div
                [ class "card-body p-3 grid gap-y-2" ]
                [ cardHeader item
                , SectorAndLaps.view item
                , RivalGapSparkline.view lapHistory allCars item
                ]
            ]
        ]


cardHeader : CarAt -> Html msg
cardHeader item =
    div
        [ class "grid grid-cols-[auto_1fr] items-center gap-x-2" ]
        [ CarNumberBadge.view item.metadata
        , div
            [ class "text-[12px] truncate" ]
            [ text (Driver.toFullName item.currentDriver) ]
        ]


statusBadge : Status -> Html msg
statusBadge status =
    case status of
        InPit ->
            div
                [ class "grid place-items-center w-4 h-4 rounded-full border border-[hsl(0_0%_100%/0.6)] text-[9px] font-bold leading-none" ]
                [ text "P" ]

        Retired ->
            div
                [ class "py-px px-1 rounded-[3px] bg-[hsl(0_70%_45%)] text-[9px] font-bold tracking-wider" ]
                [ text "RET" ]

        _ ->
            text ""


positionLabel : CarAt -> Html msg
positionLabel item =
    div
        [ class "flex items-center gap-x-1 text-[10px] before:block before:content-[''] before:w-[0.2em] before:h-[1em] before:rounded-[2px] before:[background-color:var(--class-color)]"
        , attribute "style" ("--class-color: " ++ (Class.toColor item.metadata.class).value ++ ";")
        ]
        [ text ("P" ++ String.fromInt item.standing.position) ]


gapsRow : CarAt -> Html msg
gapsRow item =
    div
        [ class "grid grid-cols-[1fr] items-baseline text-[10px] opacity-75" ]
        [ gapCell "Interval" item.standing.intervalToAhead ]


gapCell : String -> Gap -> Html msg
gapCell label gap =
    div
        [ class "grid grid-cols-[auto_1fr] items-baseline gap-x-1 tabular-nums" ]
        [ div [ class "opacity-70" ]
            [ text label ]
        , div
            [ class "text-right" ]
            [ text (Gap.toString gap) ]
        ]
