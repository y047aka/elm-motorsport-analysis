module View.PitLane exposing (view)

{-| The cars in the pit lane at the moment the page is showing: the ones being
served, and the ones already driving away down the lane.

The lane is the tracker's own, and answers to no click: it says who is in the lane
at all rather than who the reader picked. Everything a row shows is a reading of
the snapshot -- [`CarAt.inLane`](Motorsport-Race-Snapshot#inLane) is where the two
crossings and the handover come from -- so the list asks nothing of the cars' laps.

@docs view

-}

import Html exposing (Html, div, span, text)
import Html.Attributes exposing (class)
import Html.Keyed
import Motorsport.Driver as Driver
import Motorsport.Instant as Instant
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Lane, Snapshot)
import Motorsport.Status as Status
import View.CarNumberBadge as CarNumberBadge
import View.ClassMark as ClassMark


{-| The list, headed by the count of the cars being served.
-}
view : Snapshot -> Html msg
view snapshot =
    let
        inLane : List ( CarAt, Lane )
        inLane =
            Snapshot.toList snapshot
                |> List.filterMap (\car -> Maybe.map (Tuple.pair car) car.inLane)
                |> List.sortWith servedFirst

        beingServed : Int
        beingServed =
            List.length (List.filter (isBeingServed << Tuple.first) inLane)
    in
    div [ class "h-full min-h-0 grid grid-rows-[auto_minmax(0,1fr)] gap-y-1" ]
        [ div [ class "text-[10px] font-bold uppercase tracking-wide text-muted-foreground" ]
            [ text ("In the pits · " ++ String.fromInt beingServed) ]
        , if List.isEmpty inLane then
            div [ class "text-xs text-muted-foreground" ]
                [ text "No car is in the pit lane." ]

          else
            Html.Keyed.node "div"
                [ class "min-h-0 overflow-y-auto grid auto-rows-[1.375rem] content-start gap-y-0.5" ]
                (List.map row inLane)
        ]


{-| Cars still being served head the list, each new arrival above the cars it
arrived behind; cars already driving away follow, the one that left the lane last
above the ones that left before it.
-}
servedFirst : ( CarAt, Lane ) -> ( CarAt, Lane ) -> Order
servedFirst ( a, aLane ) ( b, bLane ) =
    case ( isBeingServed a, isBeingServed b ) of
        ( True, True ) ->
            Instant.compare bLane.enteredAt aLane.enteredAt

        ( True, False ) ->
            LT

        ( False, True ) ->
            GT

        ( False, False ) ->
            Instant.compare bLane.exitedAt aLane.exitedAt


isBeingServed : CarAt -> Bool
isBeingServed car =
    car.status == Status.InPit


{-| A car in the lane: its number, and who is in the car -- or the change of driver
just made in the box.
-}
row : ( CarAt, Lane ) -> ( String, Html msg )
row ( car, lane ) =
    let
        away =
            car.status == Status.OutLap

        who =
            case lane.handover of
                Just ( handedOver, tookOver ) ->
                    Driver.toHandover handedOver tookOver

                Nothing ->
                    Driver.toInitialAndSurname car.currentDriver

        chip classes label =
            span [ class ("inline-flex items-center justify-center rounded-full border px-1.5 text-[9px] font-bold leading-4 " ++ classes) ]
                [ text label ]
    in
    ( car.metadata.carNumber
    , div [ class "grid grid-cols-[auto_auto_1fr_auto] items-center gap-2 rounded py-0.5" ]
        [ ClassMark.view car.metadata
        , CarNumberBadge.viewRow car.metadata
        , div
            [ class
                (if away then
                    "text-xs truncate text-muted-foreground"

                 else
                    "text-xs truncate"
                )
            ]
            [ text who ]
        , if away then
            chip "bg-card border-border text-muted-foreground" "OUT"

          else
            chip "bg-card border-border" "PIT"
        ]
    )
