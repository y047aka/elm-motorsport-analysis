module View.CarDetail.Header exposing (view)

{-| Who the car is and where it stands: the line a classification prints, with
the two cars it is actually racing on either side of it.

@docs view

-}

import Html exposing (Html, div, img, text)
import Html.Attributes exposing (alt, attribute, class, src)
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Status exposing (Status(..))
import Motorsport.Wec.Class as Class
import Motorsport.Widget.Leaderboard exposing (viewPositionChange)
import View.CarNumberBadge as CarNumberBadge


{-| `startPosition` is where the car began, which the round's summary estimates
off the opening lap rather than reading off a grid sheet. `behind` is the car
next in the running order measured against this one, which no `CarAt` carries:
a car is given the gap to the one ahead of it, never the one behind.
-}
view :
    { startPosition : Maybe Int
    , behind : Maybe Gap
    }
    -> CarAt
    -> Html msg
view { startPosition, behind } item =
    div [ class "grid gap-y-2" ]
        [ who item
        , standing { startPosition = startPosition, behind = behind } item
        ]


{-| The car itself, side on, in the width the name and the drivers leave beside
them: the panel is wide enough that a line of text does not fill it, where a row
of the photograph's own took more of the panel's height than the lap times below
it.
-}
portrait : Maybe String -> CarAt -> Html msg
portrait carImageUrl item =
    case carImageUrl of
        Just url ->
            img
                [ src url
                , alt (item.metadata.carNumber ++ " " ++ item.metadata.team)
                , class "self-center w-[140px] h-auto object-contain"
                ]
                []

        Nothing ->
            text ""


who : CarAt -> Html msg
who item =
    div [ class "grid grid-cols-[auto_1fr_auto_auto] items-start gap-x-3" ]
        [ CarNumberBadge.view item.metadata
        , div [ class "grid gap-y-0.5 min-w-0" ]
            -- The class badge does not wrap, so without a floor of its own this
            -- line is as wide as the team's name and pushes the car's picture
            -- off the end of the row rather than cutting the name.
            [ div [ class "flex items-center gap-x-2 min-w-0" ]
                [ classBadge item
                , div [ class "text-[14px] truncate" ] [ text item.metadata.team ]
                ]
            , lineup item
            ]
        , portrait item.metadata.imageUrl item
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
        [ statCell "Pos" (text ("P" ++ String.fromInt item.standing.position))
        , statCell "Class" (text ("P" ++ String.fromInt item.standing.positionInClass))
        , statCell "Position" (viewPositionChange { startPosition = startPosition, position = item.standing.position })
        , statCell "Laps" (text (String.fromInt item.standing.lapsCompleted))
        , statCell "Leader" (text (Gap.toString item.standing.gapToLeader))
        , statCell "Ahead / behind"
            (text
                (Gap.toString item.standing.intervalToAhead
                    ++ " / "
                    ++ (behind |> Maybe.map Gap.toString |> Maybe.withDefault "-")
                )
            )
        ]


statCell : String -> Html msg -> Html msg
statCell label value =
    div
        [ class "grid gap-y-px justify-items-center py-1 px-0.5 border-l border-l-border first:border-l-0" ]
        [ div [ class "text-[8px] uppercase tracking-[0.03em] text-muted-foreground" ] [ text label ]
        , div [ class "text-[12px] tabular-nums" ] [ value ]
        ]


statusBadge : Status -> Html msg
statusBadge status =
    case status of
        InPit ->
            badge "border border-border" "IN PIT"

        OutLap ->
            badge "border border-border" "OUT LAP"

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
