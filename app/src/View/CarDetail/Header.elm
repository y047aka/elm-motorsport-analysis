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
import Motorsport.Leaderboard exposing (viewPositionChange)
import Motorsport.Race.Snapshot exposing (CarAt)
import Motorsport.Status exposing (Status(..))
import Motorsport.Wec.Class as Class
import View.CarNumberBadge as CarNumberBadge


{-| `startPosition` is where the car began, which the round's summary estimates
off the opening lap rather than reading off a grid sheet.

The three gaps are the caller's rather than read off the car, because a `CarAt`
carries them measured against the field and this line reports the car's class.
The two are not the same race: the car ahead of an LMGT3 car on the road is
often a Hypercar lapping it, and the field's leader is several laps up in a
class it is not racing. The legend under the charts names the class rivals, so
gaps taken against the field here would be the same shape as gaps taken against
the class there, and read as the same thing.

`onClose` closes the column. It is `Nothing` for the only column on show, which
is the one the middle of the page is never without.

-}
view :
    { startPosition : Maybe Int
    , toLeader : Gap
    , toAhead : Gap
    , toBehind : Gap
    , onClose : Maybe msg
    }
    -> CarAt
    -> Html msg
view { startPosition, toLeader, toAhead, toBehind, onClose } item =
    div [ class "grid gap-y-2" ]
        [ who onClose item
        , standing
            { startPosition = startPosition
            , toLeader = toLeader
            , toAhead = toAhead
            , toBehind = toBehind
            }
            item
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
                , class "self-center w-[120px] h-auto object-contain"
                ]
                []

        Nothing ->
            text ""


who : Maybe msg -> CarAt -> Html msg
who onClose item =
    div [ class "grid grid-cols-[auto_1fr_auto_auto] items-start gap-x-3" ]
        [ CarNumberBadge.view item.metadata
        , div [ class "grid gap-y-0.5 min-w-0" ]
            -- A line each. Sharing one with the class badge left the name what
            -- the badge did not want, which in a column is not much: the badge
            -- does not wrap, and the name is the part worth reading in full.
            [ classBadge item
            , div [ class "text-[14px] truncate" ] [ text item.metadata.team ]
            , currentDriver item
            ]
        , portrait item.metadata.imageUrl item
        , corner onClose item.status
        ]


{-| The top right of the header. The status badge has always been what sits
there; the close button joins it only where there is a column to close, so a
panel given the cell whole is drawn exactly as it was.
-}
corner : Maybe msg -> Status -> Html msg
corner onClose status =
    case onClose of
        Nothing ->
            statusBadge status

        Just msg ->
            div [ class "flex items-start gap-x-1" ]
                [ statusBadge status
                , button
                    [ onClick msg
                    , attribute "aria-label" "Close this column"
                    , title "Close this column"
                    , class "grid place-items-center w-5 h-5 rounded-md text-[11px] text-muted-foreground cursor-pointer transition-colors hover:bg-accent hover:text-accent-foreground"
                    ]
                    [ text "✕" ]
                ]


classBadge : CarAt -> Html msg
classBadge item =
    div
        [ class "flex items-center gap-x-1 text-[11px] font-bold whitespace-nowrap before:block before:content-[''] before:w-[0.2em] before:h-[1em] before:rounded-[2px] before:[background-color:var(--class-color)]"
        , attribute "style" ("--class-color: " ++ Class.toColor item.metadata.class ++ ";")
        ]
        [ text (Class.toString item.metadata.class) ]


{-| The driver out on the car, and only that one. The whole entry is three names
on a line, which in a column this wide is three lines of a header that has four
of them; which of the three is driving is the part that changes as the race runs
and the part a reader is looking for.
-}
currentDriver : CarAt -> Html msg
currentDriver item =
    div [ class "text-[11px] truncate" ]
        [ text (Driver.toInitialAndSurname item.currentDriver) ]


{-| The line a classification prints. The first four cells are the car's place
in the field and in its class; the last two are the race it is actually in, and
say so on themselves rather than leaving a reader to assume which of the two
they belong to.
-}
standing : { startPosition : Maybe Int, toLeader : Gap, toAhead : Gap, toBehind : Gap } -> CarAt -> Html msg
standing { startPosition, toLeader, toAhead, toBehind } item =
    div [ class "border border-border rounded-lg grid grid-cols-6" ]
        [ statCell "Pos" (text ("P" ++ String.fromInt item.standing.position))
        , statCell "Class" (text ("P" ++ String.fromInt item.standing.positionInClass))
        , statCell "Position" (viewPositionChange { startPosition = startPosition, position = item.standing.position })
        , statCell "Laps" (text (String.fromInt item.standing.lapsCompleted))
        , statCell "Class leader" (text (Gap.toString toLeader))
        , statCell "Class ahead / behind"
            (text (Gap.toString toAhead ++ " / " ++ Gap.toString toBehind))
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
