module View.EnergyBar exposing (bar, width)

{-| The standings' Energy column: how much of its tank a car has left, in the units
the race is run in -- laps of the window its class runs on.

The fill runs from the left rather than from a centre, because this is a level and
not a difference: what is left is what is drawn. Over the fill sits a band, which is
the class's own disagreement between its runs -- the error the reading admits to,
drawn rather than hidden. A car past its window is marked at the right edge instead
of drawn over it: an overrun is a fact about the car, not a bar that has outgrown its
track.

Where the reading says nothing, the cell says which of its reasons it is. A class
that has not stopped ten times yet, a class whose race is not run on a window, and a
car that has yet to run a lap at pace are three different silences, and the reader is
owed the difference.

@docs bar, width

-}

import Html exposing (Html, div)
import Html.Attributes exposing (class, style, title)
import Motorsport.Analysis.Tank as Tank exposing (Tank)


{-| How wide the column is, in pixels -- the track `columnSpec` gives it.
-}
width : Float
width =
    64


{-| The tank, filled to the share of the window the car has left.

`Nothing` is a car this round's field does not hold: an empty cell keeps the row's
columns lined up and says nothing, which is what is known.

-}
bar : Maybe Tank -> Html msg
bar reading =
    case reading of
        Nothing ->
            div [ class "h-3" ] []

        Just (Tank.Unreadable reason) ->
            div
                [ class "h-3 grid place-items-center text-[10px] leading-none text-muted-foreground"
                , title (reasonOf reason)
                ]
                [ div [ class "w-3 h-px bg-muted-foreground" ] [] ]

        Just (Tank.Running level) ->
            tank level [ fill level, band level ] (runningTitle level)

        Just (Tank.Overrun level) ->
            tank level [ full, mark ] (overrunTitle level)


tank : Tank.Level -> List (Html msg) -> String -> Html msg
tank level drawn labelled =
    div
        [ class "relative h-3 rounded-[2px] bg-muted overflow-hidden"
        , title labelled
        ]
        drawn


{-| What is left, from the left edge.
-}
fill : Tank.Level -> Html msg
fill level =
    div
        [ class "absolute top-0 left-0 h-full bg-primary/80"
        , style "width" (percent (100 * level.fraction))
        ]
        []


{-| The class's disagreement, straddling the edge of what is left.

A band that runs off either end is cut at the end rather than drawn as a wider bar:
the window is the whole track, and the uncertainty lives inside it.

-}
band : Tank.Level -> Html msg
band level =
    let
        share =
            100 * toFloat level.band / toFloat level.window

        edge =
            100 * level.fraction - share / 2
    in
    div
        [ class "absolute top-0 h-full bg-primary/30"
        , style "left" (percent (clampShare edge))
        , style "width" (percent (clampShare share))
        ]
        []


{-| An overrun: the tank is gone, and so the fill would be the whole bar; what is
drawn is the mark at the end, which is the part that is news.
-}
full : Html msg
full =
    div [ class "absolute top-0 left-0 h-full w-full bg-muted" ] []


mark : Html msg
mark =
    div [ class "absolute top-0 right-0 h-full w-1 bg-destructive" ] []


clampShare : Float -> Float
clampShare =
    Basics.clamp 0 100


percent : Float -> String
percent value =
    String.fromFloat value ++ "%"


runningTitle : Tank.Level -> String
runningTitle level =
    laps level.laps ++ " left on a " ++ windowOf level ++ " (±" ++ laps level.band ++ ")"


overrunTitle : Tank.Level -> String
overrunTitle level =
    laps level.laps ++ " past its " ++ windowOf level


windowOf : Tank.Level -> String
windowOf level =
    String.fromInt level.window ++ "-lap window"


laps : Int -> String
laps count =
    if count == 1 then
        "1 lap"

    else
        String.fromInt count ++ " laps"


reasonOf : Tank.Reason -> String
reasonOf reason =
    case reason of
        Tank.NoWindow ->
            "No window yet: this class has not stopped ten times with the field unheld"

        Tank.NotOnWindow ->
            "Not a race run on a window: this class's runs disagree by more than a quarter of their own top decile"

        Tank.NoRun ->
            "No lap at pace yet on the tank it is running"
