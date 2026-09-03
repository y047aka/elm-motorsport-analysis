module Motorsport.Widget.Compare.CarSummary exposing (carSummary, placeholderCard)

{-| Per-car summary card for the Compare widget: who the car is, and who is
driving it. Plus the placeholder that fills an unselected slot.

@docs carSummary, placeholderCard

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)
import Motorsport.Driver as Driver
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Status exposing (Status(..))
import Motorsport.Widget.CarNumberBadge as CarNumberBadge


{-| Subtle placeholder filling an unselected slot. Nudges toward the selector above.
-}
placeholderCard : Html msg
placeholderCard =
    div
        [ class "grid place-items-center min-h-[100px] border border-dashed border-border rounded-lg text-[11px] text-muted-foreground" ]
        [ text "車両を追加" ]


carSummary : CarAt -> Html msg
carSummary item =
    div
        [ class "grid grid-cols-[auto_1fr_auto] items-start gap-x-2" ]
        [ CarNumberBadge.view item.metadata
        , div
            [ class "grid gap-y-0.5" ]
            [ div [ class "text-[14px]" ]
                [ text item.metadata.team ]
            , driverList item
            ]
        , statusBadge item.status
        ]


{-| As in the leaderboard, emphasizes the driver currently at the wheel and dims
the others.
-}
driverList : CarAt -> Html msg
driverList item =
    let
        isCurrentDriver driver =
            Driver.isSame driver item.currentDriver
    in
    div
        [ class "flex flex-wrap gap-x-2 gap-y-0.5 text-[11px]" ]
        (List.map
            (\driver ->
                div
                    [ class
                        (if isCurrentDriver driver then
                            "opacity-100"

                         else
                            "opacity-40"
                        )
                    ]
                    [ text (Driver.toFullName driver) ]
            )
            item.metadata.drivers
        )


statusBadge : Status -> Html msg
statusBadge status =
    case status of
        InPit ->
            div
                [ class "grid place-items-center py-px px-1.5 rounded-full border border-border text-[9px] font-bold" ]
                [ text "IN PIT" ]

        Retired ->
            div
                [ class "py-px px-1.5 rounded-md bg-destructive/10 text-destructive text-[9px] font-bold tracking-wider" ]
                [ text "RETIRED" ]

        _ ->
            text ""
