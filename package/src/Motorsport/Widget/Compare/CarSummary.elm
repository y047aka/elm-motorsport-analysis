module Motorsport.Widget.Compare.CarSummary exposing (carSummary)

{-| Per-car summary card for the Compare widget: who the car is, and who is
driving it.

@docs carSummary

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class, style)
import Motorsport.Driver as Driver
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Status exposing (Status(..))
import Motorsport.Widget.CarNumberBadge as CarNumberBadge


{-| `isFocused` marks the one car the selection is; the others are the rivals
derived from it, and carry the marking the selector gives an unselected chip.
-}
carSummary : Bool -> CarAt -> Html msg
carSummary isFocused item =
    div
        [ class "grid grid-cols-[auto_1fr_auto] items-start gap-x-2 rounded-lg p-2"
        , style "border" ("1px solid " ++ markColor isFocused item)
        , style "background-color" (markFill isFocused item)
        ]
        [ CarNumberBadge.view item.metadata
        , div
            [ class "grid gap-y-0.5" ]
            [ div [ class "text-[14px]" ]
                [ text item.metadata.team ]
            , currentDriverName item
            ]
        , statusBadge item.status
        ]


{-| The chip's own vocabulary, applied to a card: the focused car is drawn in
its manufacturer's colour, and the rest are left in the border colour.
-}
markColor : Bool -> CarAt -> String
markColor isFocused item =
    if isFocused then
        item.metadata.manufacturer.color

    else
        "transparent"


markFill : Bool -> CarAt -> String
markFill isFocused item =
    if isFocused then
        "oklch(from " ++ item.metadata.manufacturer.color ++ " l c h / 0.3)"

    else
        "transparent"


currentDriverName : CarAt -> Html msg
currentDriverName item =
    div
        [ class "text-[11px]" ]
        [ text (Driver.toFullName item.currentDriver) ]


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
