module View.CarDetail.Header exposing (view)

{-| Who the car is and where it stands: the line a classification prints, with
the two cars it is actually racing on either side of it.

@docs view

-}

import Html exposing (Html, button, div, img, text)
import Html.Attributes exposing (alt, attribute, class, src, title)
import Html.Events exposing (onClick)
import Motorsport.Driver as Driver
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Leaderboard exposing (viewPositionChangeInline)
import Motorsport.Position as Position exposing (Position)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Status exposing (Status(..))
import Motorsport.Wec.Class as Class
import View.CarNumberBadge as CarNumberBadge


{-| `startPosition` is where the car began, which the round's summary estimates
off the opening lap rather than reading off a grid sheet.

`toLeader` is the caller's rather than read off the car, because a `CarAt`
carries the gap to the field's leader and this line reports the car's class --
which for an LMGT3 car is several laps and another race away.

`onClose` closes the column and `grip` carries it along the strip, both
`Nothing` for the only column on show.

-}
view :
    { startPosition : Maybe Position
    , toLeader : Gap
    , onClose : Maybe msg
    , grip : Maybe (Html msg)
    }
    -> CarAt
    -> Html msg
view { startPosition, toLeader, onClose, grip } item =
    div [ class "grid gap-y-2" ]
        [ nameplate { startPosition = startPosition, onClose = onClose, grip = grip } item
        , standing toLeader item
        ]


portrait : Maybe String -> CarAt -> Html msg
portrait carImageUrl item =
    case carImageUrl of
        Just url ->
            img
                [ src url
                , alt (item.metadata.carNumber ++ " " ++ item.metadata.team)

                -- Through the last column, which is the close button's on the
                -- row above.
                , class "col-start-3 -col-end-1 row-start-2 justify-self-end self-center w-[104px] h-auto object-contain"
                ]
                []

        Nothing ->
            text ""


{-| Two rows: where the car stands, and who it is.
-}
nameplate : { startPosition : Maybe Position, onClose : Maybe msg, grip : Maybe (Html msg) } -> CarAt -> Html msg
nameplate { startPosition, onClose, grip } item =
    div [ class "grid grid-cols-[auto_1fr_auto_auto] items-start gap-x-3 gap-y-1.5" ]
        [ div [ class "col-start-1 col-span-2 row-start-1 flex items-center gap-x-2 min-w-0" ]
            [ fieldPosition startPosition item
            , classBadge item
            ]
        , div [ class "col-start-4 row-start-1" ] [ corner { onClose = onClose, grip = grip } item.status ]

        -- Centred rather than hung from the top: the three are different
        -- heights, and the tallest would otherwise set where the others begin.
        , div [ class "col-start-1 row-start-2 self-center" ] [ CarNumberBadge.view item.metadata ]
        , div [ class "col-start-2 row-start-2 self-center grid gap-y-0.5 min-w-0" ]
            [ div [ class "text-[12px] truncate" ] [ text item.metadata.team ]
            , currentDriver item
            ]
        , portrait item.metadata.imageUrl item
        ]


corner : { onClose : Maybe msg, grip : Maybe (Html msg) } -> Status -> Html msg
corner { onClose, grip } status =
    case List.filterMap identity [ grip, Maybe.map closeButton onClose ] of
        [] ->
            statusBadge status

        controls ->
            div [ class "flex items-start gap-x-1" ] (statusBadge status :: controls)


closeButton : msg -> Html msg
closeButton msg =
    button
        [ onClick msg
        , attribute "aria-label" "Close this column"
        , title "Close this column"
        , class "grid place-items-center w-5 h-5 rounded-md text-[11px] text-muted-foreground cursor-pointer transition-colors hover:bg-accent hover:text-accent-foreground"
        ]
        [ text "✕" ]


{-| The field's place and not the class's, which the strip below reports.
-}
fieldPosition : Maybe Position -> CarAt -> Html msg
fieldPosition startPosition item =
    div [ class "flex items-center gap-x-1.5 text-[12px] tabular-nums whitespace-nowrap" ]
        [ text (Position.toOrdinal item.standing.position)
        , viewPositionChangeInline { startPosition = startPosition, position = item.standing.position }
        ]


classBadge : CarAt -> Html msg
classBadge item =
    div
        [ class "flex items-center gap-x-1 text-[12px] whitespace-nowrap before:block before:content-[''] before:w-[0.2em] before:h-[1em] before:rounded-[2px] before:[background-color:var(--class-color)]"
        , attribute "style" ("--class-color: " ++ Class.toColor item.metadata.class ++ ";")
        ]
        [ text (Class.toString item.metadata.class) ]


currentDriver : CarAt -> Html msg
currentDriver item =
    div [ class "text-[11px] truncate" ]
        [ text (Driver.toInitialAndSurname item.currentDriver) ]


standing : Gap -> CarAt -> Html msg
standing toLeader item =
    div [ class "border border-border rounded-lg grid grid-cols-3" ]
        [ statCell "Class" (text (Position.toOrdinal item.standing.positionInClass))
        , statCell "Laps" (text (String.fromInt item.standing.lapsCompleted))
        , statCell "Class leader" (text (Gap.toString toLeader))
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
