module View.PitLane exposing (view)

{-| The cars in the pit lane at the moment the page is showing: the ones being
served, and the ones already driving away down the lane.

The lane is the tracker's own, and answers to no click: it says who is in the
lane at all rather than who the reader picked.

@docs view

-}

import Html exposing (Html, div, span, text)
import Html.Attributes exposing (class)
import Html.Keyed
import List.Extra
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Status as Status
import View.CarNumberBadge as CarNumberBadge
import View.ClassMark as ClassMark


{-| The list, headed by the count of the cars being served.
-}
view : List Car -> Snapshot -> Html msg
view cars snapshot =
    let
        clock : { elapsed : Instant }
        clock =
            { elapsed = Snapshot.elapsed snapshot }

        inLane : List InLane
        inLane =
            Snapshot.toList snapshot
                |> List.filter (Status.inPitLane << .status)
                |> List.map (inLaneOf clock cars)
                |> List.sortWith servedFirst

        beingServed : Int
        beingServed =
            List.length (List.filter isBeingServed inLane)
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


{-| A car in the lane, with what its own two laps under way say at this moment,
and the two crossings of the lane that say when.
-}
type alias InLane =
    { car : CarAt
    , handover : Maybe ( Driver, Driver )
    , enteredAt : Maybe Instant
    , exitedAt : Maybe Instant
    }


inLaneOf : { elapsed : Instant } -> List Car -> CarAt -> InLane
inLaneOf clock cars car =
    let
        laps =
            cars
                |> List.Extra.find (\raceCar -> raceCar.metadata.carNumber == car.metadata.carNumber)
                |> Maybe.map .laps
                |> Maybe.withDefault []

        currentLap =
            Lap.findCurrentLap clock laps
    in
    { car = car
    , handover = Maybe.map2 handedOver (Lap.findLastLapAt clock laps) currentLap
    , enteredAt = currentLap |> Maybe.andThen Lap.pitEntryAt
    , exitedAt = currentLap |> Maybe.andThen Lap.pitExitAt
    }


{-| The change of driver made in the box: the two laps the car has under way
disagreeing about who is in the car.
-}
handedOver : Lap -> Lap -> Maybe ( Driver, Driver )
handedOver cameIn goesOut =
    if Driver.isSame cameIn.driver goesOut.driver then
        Nothing

    else
        Just ( cameIn.driver, goesOut.driver )


{-| Cars still being served head the list, each new arrival above the cars it
arrived behind; cars already driving away follow, the one that left the lane last
above the ones that left before it.
-}
servedFirst : InLane -> InLane -> Order
servedFirst a b =
    case ( isBeingServed a, isBeingServed b ) of
        ( True, True ) ->
            newestFirst a.enteredAt b.enteredAt

        ( True, False ) ->
            LT

        ( False, True ) ->
            GT

        ( False, False ) ->
            newestFirst a.exitedAt b.exitedAt


isBeingServed : InLane -> Bool
isBeingServed entry =
    entry.car.status == Status.InPit


{-| The newer crossing first; a crossing the feed times on neither side of the
stop sits at the foot.
-}
newestFirst : Maybe Instant -> Maybe Instant -> Order
newestFirst a b =
    case ( a, b ) of
        ( Just x, Just y ) ->
            Instant.compare y x

        ( Just _, Nothing ) ->
            LT

        ( Nothing, Just _ ) ->
            GT

        ( Nothing, Nothing ) ->
            EQ


{-| A car in the lane: its number, and who is in the car -- or the change of
driver just made in the box.

The row is keyed by the car's number, which is why it comes back as a pair.

-}
row : InLane -> ( String, Html msg )
row entry =
    let
        away =
            entry.car.status == Status.OutLap

        who =
            case entry.handover of
                Just ( handedOver, tookOver ) ->
                    Driver.toHandover handedOver tookOver

                Nothing ->
                    Driver.toInitialAndSurname entry.car.currentDriver

        chip classes label =
            span [ class ("inline-flex items-center justify-center rounded-full border px-1.5 text-[9px] font-bold leading-4 " ++ classes) ]
                [ text label ]
    in
    ( entry.car.metadata.carNumber
    , div [ class "grid grid-cols-[auto_auto_1fr_auto] items-center gap-2 rounded py-0.5" ]
        [ ClassMark.view entry.car.metadata
        , CarNumberBadge.viewRow entry.car.metadata
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
