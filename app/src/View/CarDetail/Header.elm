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
import Motorsport.Position as Position exposing (Position)
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
directly below.

`onClose` closes the column, and is `Nothing` for the only column on show.

-}
view :
    { startPosition : Maybe Position
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


{-| The car itself, side on, at the right of the row the badge and the name are
on. Its width is the name's loss, the name being the one thing on the row with
more to say than fits, and a car in profile stays legible far smaller than a
string of words does.
-}
portrait : Maybe String -> CarAt -> Html msg
portrait carImageUrl item =
    case carImageUrl of
        Just url ->
            img
                [ src url
                , alt (item.metadata.carNumber ++ " " ++ item.metadata.team)

                -- To the end of the row: the last column is the close
                -- button's, which is on the row above, and a picture stopping
                -- short of the edge for a button that is not beside it reads
                -- as a margin nothing asked for.
                , class "col-start-3 -col-end-1 row-start-2 justify-self-end self-center w-[104px] h-auto object-contain"
                ]
                []

        Nothing ->
            text ""


{-| Two rows: where the car stands, and who it is.

The standing -- its place in the field, and the class it holds that place in --
is not part of the car's name and does not belong on the line with it. Put
above, it leaves the number badge to start where the team's name starts, the
two of them being the one thing and read together, instead of the badge sitting
a line higher than everything it labels. Everything below this line is the
class's, so the field's place is said once, here.

Within the lower row the name has a line to itself: sharing one with the badges
left it what they did not want, which in a column is not much, and the name is
the part worth reading in full.

-}
who : { startPosition : Maybe Position, onClose : Maybe msg } -> CarAt -> Html msg
who { startPosition, onClose } item =
    div [ class "grid grid-cols-[auto_1fr_auto_auto] items-start gap-x-3 gap-y-1.5" ]
        [ div [ class "col-start-1 col-span-2 row-start-1 flex items-center gap-x-2 min-w-0" ]
            [ overall startPosition item
            , classBadge item
            ]
        , div [ class "col-start-4 row-start-1" ] [ corner onClose item.status ]

        -- The three of the lower row are centred on it rather than hung from
        -- its top: they are three heights of the same thing, and the tallest
        -- of them deciding where the other two begin left the name and the
        -- picture riding high against a badge neither of them matches.
        , div [ class "col-start-1 row-start-2 self-center" ] [ CarNumberBadge.view item.metadata ]
        , div [ class "col-start-2 row-start-2 self-center grid gap-y-0.5 min-w-0" ]
            [ -- Level with the position and the class badge above it: the
              -- header says four short things and one long one, and the long
              -- one is found by its length rather than by its size.
              div [ class "text-[12px] truncate" ] [ text item.metadata.team ]
            , currentDriver item
            ]
        , portrait item.metadata.imageUrl item
        ]


{-| The top right of the header: the status badge, and beside it the close
button wherever there is more than one column to close.
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
drawn no larger than the class badge beside it: none of the three is read
before the others.
-}
overall : Maybe Position -> CarAt -> Html msg
overall startPosition item =
    div [ class "flex items-center gap-x-1.5 text-[12px] tabular-nums whitespace-nowrap" ]
        [ text (Position.toOrdinal item.standing.position)
        , movement startPosition item.standing.position
        ]


{-| How far the car has come since the start, and nothing at all where there is
nothing to say. A cell of its own could print a dash for that and be read as an
empty cell; beside a position, a dash reads as part of the position.
-}
movement : Maybe Position -> Position -> Html msg
movement startPosition position =
    case Maybe.map (\start -> start - position) startPosition of
        Nothing ->
            text ""

        Just 0 ->
            text ""

        Just _ ->
            -- The shared cell draws its arrow bold, which is right in a column
            -- of them and wrong on a line of text. `.x > div` outranks the
            -- `.font-bold` the cell sets on itself, so the weight is settled
            -- here rather than by changing what the cell is everywhere.
            div [ class "[&>div]:font-normal" ]
                [ viewPositionChange { startPosition = startPosition, position = position } ]


classBadge : CarAt -> Html msg
classBadge item =
    div
        [ class "flex items-center gap-x-1 text-[12px] whitespace-nowrap before:block before:content-[''] before:w-[0.2em] before:h-[1em] before:rounded-[2px] before:[background-color:var(--class-color)]"
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


{-| The three readings neither the line above nor the section below gives:
where the car stands in its class, how far it has come, and how far that is
from the front of the class.
-}
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
