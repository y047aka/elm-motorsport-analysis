module Motorsport.Widget.SelectedCarsStrip exposing (view)

{-| Widget showing the current overall top cars as side-by-side cards with their
last-lap results, bests, and sector performance. Gives an at-a-glance view of
the front of the race without requiring any selection.

@docs view

-}

import Html exposing (Html, button, div, text)
import Html.Attributes as Attributes exposing (class)
import Html.Events exposing (onClick)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Widget.SelectedCarsStrip.CarCard as CarCard


{-| `offset` is the 0-based position of the first card in the visible window.
`onScrollTo` receives the target offset. Out-of-range offsets are clamped
internally, so callers may store them as-is.
-}
view :
    { offset : Int
    , onScrollTo : Int -> msg
    }
    -> Snapshot
    -> Html msg
view config snapshot =
    let
        lapHistory =
            Snapshot.lapHistory snapshot

        allCars =
            Snapshot.toList snapshot

        maxOffset =
            max 0 (List.length allCars - displayCount)

        offset =
            clamp 0 maxOffset config.offset

        window =
            allCars
                |> List.drop offset
                |> List.take displayCount
    in
    case window of
        [] ->
            emptyState

        _ ->
            div
                [ class "grid grid-cols-[auto_1fr_auto] items-center gap-2" ]
                [ navButton "◀" (config.onScrollTo (offset - 1)) (offset <= 0)
                , div
                    [ class "grid grid-flow-col auto-cols-[minmax(0,1fr)] gap-2" ]
                    (List.map (CarCard.view lapHistory allCars) window)
                , navButton "▶" (config.onScrollTo (offset + 1)) (offset >= maxOffset)
                ]


{-| Number of cars shown at once. The carousel scrolls one car at a time.
-}
displayCount : Int
displayCount =
    5


navButton : String -> msg -> Bool -> Html msg
navButton label msg isDisabled =
    button
        [ onClick msg
        , Attributes.disabled isDisabled
        , class "inline-flex items-center justify-center size-8 rounded-full text-xs cursor-pointer transition-colors bg-card hover:bg-accent hover:text-accent-foreground disabled:opacity-40 disabled:pointer-events-none"
        ]
        [ text label ]


emptyState : Html msg
emptyState =
    div
        [ class "grid place-items-center text-[11px] opacity-50" ]
        [ text "No cars on track" ]
