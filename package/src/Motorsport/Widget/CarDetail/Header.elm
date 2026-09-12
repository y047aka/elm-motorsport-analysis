module Motorsport.Widget.CarDetail.Header exposing (view)

{-| Who the car is and where it stands: the line a classification prints, with
the two cars it is actually racing on either side of it.

@docs view

-}

import Html exposing (Html, div, text)
import Html.Attributes exposing (attribute, class)
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Status exposing (Status(..))
import Motorsport.Wec.Class as Class
import Motorsport.Widget.CarNumberBadge as CarNumberBadge


{-| `startPosition` is where the car began, which the round's summary estimates
off the opening lap rather than reading off a grid sheet. `behind` is the car
next in the running order measured against this one, which no `CarAt` carries:
a car is given the gap to the one ahead of it, never the one behind.
-}
view : { startPosition : Maybe Int, behind : Maybe Gap } -> CarAt -> Html msg
view { startPosition, behind } item =
    div [ class "grid gap-y-2" ]
        [ who item
        , standing { startPosition = startPosition, behind = behind } item
        ]


who : CarAt -> Html msg
who item =
    div [ class "grid grid-cols-[auto_1fr_auto] items-start gap-x-3" ]
        [ CarNumberBadge.view item.metadata
        , div [ class "grid gap-y-0.5 min-w-0" ]
            [ div [ class "flex items-center gap-x-2" ]
                [ classBadge item
                , div [ class "text-[14px] truncate" ] [ text item.metadata.team ]
                ]
            , lineup item
            ]
        , statusBadge item.status
        ]


classBadge : CarAt -> Html msg
classBadge item =
    div
        [ class "flex items-center gap-x-1 text-[11px] font-bold whitespace-nowrap before:block before:content-[''] before:w-[0.2em] before:h-[1em] before:rounded-[2px] before:[background-color:var(--class-color)]"
        , attribute "style" ("--class-color: " ++ Class.toColor item.metadata.class ++ ";")
        ]
        [ text (Class.toString item.metadata.class) ]


{-| Every driver entered on the car, the one out on it marked. Which of them is
driving is the thing about a car that changes without the order changing.
-}
lineup : CarAt -> Html msg
lineup item =
    div [ class "flex flex-wrap items-baseline gap-x-2 text-[11px]" ]
        (List.map (driverName item.currentDriver) item.metadata.drivers)


driverName : Driver -> Driver -> Html msg
driverName current driver =
    div
        [ class
            (if Driver.isSame current driver then
                "font-bold"

             else
                "text-muted-foreground"
            )
        ]
        [ text (Driver.toInitialAndSurname driver) ]


standing : { startPosition : Maybe Int, behind : Maybe Gap } -> CarAt -> Html msg
standing { startPosition, behind } item =
    div [ class "border border-border rounded-lg grid grid-cols-6" ]
        [ statCell "Pos" ("P" ++ String.fromInt item.standing.position)
        , statCell "Class" ("P" ++ String.fromInt item.standing.positionInClass)
        , statCell "Start" (startAndGained startPosition item)
        , statCell "Laps" (String.fromInt item.standing.lapsCompleted)
        , statCell "Leader" (Gap.toString item.standing.gapToLeader)
        , statCell "Ahead / behind"
            (Gap.toString item.standing.intervalToAhead
                ++ " / "
                ++ (behind |> Maybe.map Gap.toString |> Maybe.withDefault "-")
            )
        ]


startAndGained : Maybe Int -> CarAt -> String
startAndGained startPosition item =
    case startPosition of
        Just start ->
            let
                gained =
                    start - item.standing.position
            in
            "P"
                ++ String.fromInt start
                ++ (if gained > 0 then
                        " ▲" ++ String.fromInt gained

                    else if gained < 0 then
                        " ▼" ++ String.fromInt (abs gained)

                    else
                        ""
                   )

        Nothing ->
            "-"


statCell : String -> String -> Html msg
statCell label value =
    div
        [ class "grid gap-y-px justify-items-center py-1 px-0.5 border-l border-l-border first:border-l-0" ]
        [ div [ class "text-[8px] uppercase tracking-[0.03em] text-muted-foreground" ] [ text label ]
        , div [ class "text-[12px] tabular-nums" ] [ text value ]
        ]


statusBadge : Status -> Html msg
statusBadge status =
    case status of
        InPit ->
            badge "border border-border" "IN PIT"

        Retired ->
            badge "bg-destructive/10 text-destructive" "RETIRED"

        Checkered ->
            badge "border border-border" "FINISHED"

        _ ->
            text ""


badge : String -> String -> Html msg
badge look label =
    div
        [ class ("grid place-items-center py-px px-1.5 rounded-full text-[9px] font-bold tracking-wider " ++ look) ]
        [ text label ]
