module Motorsport.Widget.CarCardList exposing (view)

{-| Every car of the field as a card, in overall order. The cards are the
strip's; nothing here is windowed.

@docs view

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (class)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Widget.CarCard as CarCard


view : Snapshot -> Html msg
view snapshot =
    let
        lapHistory =
            Snapshot.lapHistory snapshot

        allCars =
            Snapshot.toList snapshot
    in
    case allCars of
        [] ->
            div [ class "grid place-items-center text-[11px] opacity-50" ]
                [ text "No cars on track" ]

        _ ->
            div
                [ class "grid gap-2 grid-cols-[repeat(auto-fill,minmax(260px,1fr))]" ]
                (List.map (CarCard.view lapHistory allCars) allCars)
