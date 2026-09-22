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

`toLeader` is the caller's rather than read off the car, because a `CarAt`
carries the gap to the field's leader and this line reports the car's class --
which for an LMGT3 car is several laps and another race away. It is the only gap
left here: the rivals either side are named, placed and timed in the section
directly below, which said the same two figures over again and without saying
whose they were.

`onClose` closes the column. It is `Nothing` for the only column on show, which
is the one the middle of the page is never without.

-}
view :
    { startPosition : Maybe Int
    , toLeader : Gap
    , onClose : Maybe msg
    }
    -> CarAt
    -> Html msg
view { startPosition, toLeader, onClose } item =
    div [ class "grid gap-y-2" ]
        [ who { startPosition = startPosition, onClose = onClose } item
        , standing toLeader item
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


who : { startPosition : Maybe Int, onClose : Maybe msg } -> CarAt -> Html msg
who { startPosition, onClose } item =
    div [ class "grid grid-cols-[auto_1fr_auto_auto] items-start gap-x-3" ]
        [ CarNumberBadge.view item.metadata
        , div [ class "grid gap-y-0.5 min-w-0" ]
            -- The name has a line to itself. Sharing one with the badges left
            -- it what they did not want, which in a column is not much: they do
            -- not wrap, and the name is the part worth reading in full.
            [ div [ class "flex items-center gap-x-2 min-w-0" ]
                [ overall startPosition item
                , classBadge item
                ]
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


{-| Where the car stands in the field and how far it has come to stand there,
at the top of the panel beside the class it stands there in. The three are one
fact between them -- which race this car is in, and where in it -- and drawn
alike, because none of them is read before the others. Everything under this
line is the class's, so the field's place is said once, here.
-}
overall : Maybe Int -> CarAt -> Html msg
overall startPosition item =
    div [ class "flex items-center gap-x-1.5 text-[11px] font-bold tabular-nums whitespace-nowrap" ]
        [ text ("P" ++ String.fromInt item.standing.position)
        , movement startPosition item.standing.position
        ]


{-| How far the car has come since the start, and nothing at all where there is
nothing to say. A cell of its own could print a dash for that and be read as an
empty cell; beside a position, a dash reads as part of the position.
-}
movement : Maybe Int -> Int -> Html msg
movement startPosition position =
    case Maybe.map (\start -> start - position) startPosition of
        Nothing ->
            text ""

        Just 0 ->
            text ""

        Just _ ->
            viewPositionChange { startPosition = startPosition, position = position }


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


{-| The line a classification prints, once the top of the panel has said where
the car stands in the field and the section below has named the cars either side
of it. What is left is the three readings neither of those gives: where it
stands in its class, how far it has come, and how far that is from the front of
the class.
-}
standing : Gap -> CarAt -> Html msg
standing toLeader item =
    div [ class "border border-border rounded-lg grid grid-cols-3" ]
        [ statCell "Class" (text ("P" ++ String.fromInt item.standing.positionInClass))
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
