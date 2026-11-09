module View.EnergyBar exposing (Stage(..), bar, stageOf, width)

{-| The standings' Energy column: how much of its tank a car has left, in the units
the race is run in -- laps of the window its class runs on.

The fill runs from the left rather than from a centre, because this is a level and
not a difference: what is left is what is drawn. Its colour says how to read the
length, in the four hues the flag bands are already drawn in -- see
[`View.PlaybackControls.bandColor`](View-PlaybackControls#bandColor). Over the fill
sits a band, which is the class's own disagreement between its runs -- the error the
reading admits to, drawn rather than hidden. It is drawn in the foreground and not
the fill's hue: a band matched to the fill cannot be seen on the fill.

A car past its window has nothing left to fill, so the track itself takes the level
an empty one takes. Nothing in this column is anchored to the right edge; the bar, its
colour and its band all read from the same end.

A class that is not run on a window is drawn as the one thing it does say: the laps its middle half came in on, marked at its middle stop. That is drawn in the hue a level's uncertainty band is drawn in, at the same scale, and it fills no part of the tank -- the two drawings differ by whether they answer about a car at all.

Where there is no window at all -- a class that has not stopped ten times with the field unheld -- the cell says so, which is a different fact from a spread: that class stopped often enough to describe itself, and this one did not stop often enough to be described.

@docs Stage, bar, stageOf, width

-}

import Html exposing (Html, div)
import Html.Attributes exposing (class, style, title)
import Motorsport.Analysis.Energy as Energy exposing (Tank(..))


{-| How wide the column is, in pixels -- the track `columnSpec` gives it.
-}
width : Float
width =
    64


{-| How much of the window is left, in the four levels the fill is drawn in.
-}
type Stage
    = Ample
    | Steady
    | Low
    | Critical


{-| Which level a car's fill is drawn in: quarters of the window left, counted in
whole laps so the boundaries land where the pit wall counts them.

An [`Overrun`](Motorsport-Analysis-Energy#Tank) never reaches this -- it has no fill to
colour, and is drawn as the whole track in the level an empty one takes.

-}
stageOf : Energy.Level -> Stage
stageOf level =
    let
        quarters =
            level.laps * 4
    in
    if quarters >= level.window * 3 then
        Ample

    else if quarters >= level.window * 2 then
        Steady

    else if quarters >= level.window then
        Low

    else
        Critical


{-| The tank, filled to the share of the window the car has left.

`Nothing` is a car this round's field does not hold: an empty cell keeps the row's
columns lined up and says nothing, which is what is known.

A [`Spread`](Motorsport-Analysis-Energy#Tank) is drawn on the same track and fills none of it, since it says where the class stops and not where a car is.

-}
bar : Maybe Tank -> Html msg
bar reading =
    case reading of
        Nothing ->
            div [ class "h-3" ] []

        Just Unreadable ->
            div
                [ class "h-3 grid place-items-center text-[10px] leading-none text-muted-foreground"
                , title noWindowTitle
                ]
                [ div [ class "w-3 h-px bg-muted-foreground" ] [] ]

        Just (Running level) ->
            track "bg-muted" [ fill (stageOf level) level, band level ] (runningTitle level)

        Just (Overrun level) ->
            track "bg-red-600/20" [] (overrunTitle level)

        Just (Spread spread) ->
            track "bg-muted" [ quartiles spread, middle spread ] (spreadTitle spread)


{-| The whole window, drawn as the bar is. `trackClass` is the level the track itself
takes, which only an overrun paints.
-}
track : String -> List (Html msg) -> String -> Html msg
track trackClass drawn labelled =
    div
        [ class ("relative h-3 overflow-hidden rounded-[2px] " ++ trackClass)
        , title labelled
        ]
        drawn


{-| What is left, from the left edge.
-}
fill : Stage -> Energy.Level -> Html msg
fill stage level =
    div
        [ class ("absolute top-0 left-0 h-full " ++ colorOf stage)
        , style "width" (percent (100 * level.fraction))
        ]
        []


{-| The class's disagreement, straddling the edge of what is left.

A band that runs off either end is cut at the end rather than drawn as a wider bar:
the window is the whole track, and the uncertainty lives inside it.

-}
band : Energy.Level -> Html msg
band level =
    let
        share =
            100 * toFloat level.band / toFloat level.window

        edge =
            100 * level.fraction - share / 2
    in
    div
        [ class "absolute top-0 h-full bg-foreground/25"
        , style "left" (percent (clampShare edge))
        , style "width" (percent (clampShare share))
        ]
        []


{-| The laps a class's middle half came in on, on the track the window fills.

A spread takes no stage colour and fills no part of the tank; it is drawn in the hue a level's own band is drawn in, which is the same fact about the same runs.

-}
quartiles : Energy.Stops -> Html msg
quartiles spread =
    div
        [ class "absolute top-0 h-full bg-foreground/25"
        , style "left" (percent (across spread spread.low))
        , style "width" (percent (clampShare (across spread spread.high - across spread spread.low)))
        ]
        []


{-| The lap the class's middle stop fell on.
-}
middle : Energy.Stops -> Html msg
middle spread =
    div
        [ class "absolute top-0 h-full w-px bg-muted-foreground"
        , style "left" (percent (across spread spread.median))
        ]
        []


{-| How far along the track a lap of the class's window stands.
-}
across : Energy.Stops -> Int -> Float
across spread lap =
    100 * toFloat lap / toFloat spread.window


colorOf : Stage -> String
colorOf stage =
    case stage of
        Ample ->
            "bg-green-600"

        Steady ->
            "bg-yellow-400"

        Low ->
            "bg-orange-500"

        Critical ->
            "bg-red-600"


clampShare : Float -> Float
clampShare =
    Basics.clamp 0 100


percent : Float -> String
percent value =
    String.fromFloat value ++ "%"


runningTitle : Energy.Level -> String
runningTitle level =
    laps level.laps ++ " left on a " ++ windowOf level ++ " (±" ++ laps level.band ++ ")"


overrunTitle : Energy.Level -> String
overrunTitle level =
    laps level.laps ++ " past its " ++ windowOf level


spreadTitle : Energy.Stops -> String
spreadTitle spread =
    "Not a race run on a window: half this class's stops fall between "
        ++ String.fromInt spread.low
        ++ " and "
        ++ laps spread.high
        ++ ", its middle stop on lap "
        ++ String.fromInt spread.median


windowOf : Energy.Level -> String
windowOf level =
    String.fromInt level.window ++ "-lap window"


laps : Int -> String
laps count =
    if count == 1 then
        "1 lap"

    else
        String.fromInt count ++ " laps"


{-| The one silence this column keeps: a class that has not stopped ten times with the
field unheld, which is too few runs for a top decile to say how far a tank goes.
-}
noWindowTitle : String
noWindowTitle =
    "No window: this class has not stopped ten times with the field unheld"
