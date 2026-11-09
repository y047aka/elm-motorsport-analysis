module View.EnergyBar exposing (Stage(..), bar, stageOf, width)

{-| The standings' Energy column: how much of its energy a car has left, in the units
the race is run in -- laps of the plan its class is running.

The fill runs from the left rather than from a centre, because this is a level and not a difference: what is left is what is drawn.
Its colour says how to read the length, in the four hues the flag bands are already drawn in -- see [`View.PlaybackControls`](View-PlaybackControls).
Over the fill sits a band, which is the class's own disagreement within its plan, drawn rather than hidden.
It is drawn in the foreground and not the fill's hue: a band matched to the fill cannot be seen on the fill.

A car past its plan has nothing left to fill, so the track itself takes the level an empty one takes.

A class that runs no one plan is drawn as the one thing it does say -- the laps its middle half came in on, marked at its middle stop -- and it fills none of the bar: the two drawings differ by whether they answer about a car at all.

Where there is nothing to say at all -- a class that has not stopped ten times with the field unheld -- the cell says so, which is a different fact from a spread: that class stopped often enough to describe itself, and this one did not stop often enough to be described.

@docs Stage, bar, stageOf, width

-}

import Html exposing (Html, div)
import Html.Attributes exposing (class, style, title)
import Motorsport.Analysis.Energy as Energy exposing (Energy(..))


{-| How wide the column is, in pixels -- the track `columnSpec` gives it.
-}
width : Float
width =
    64


{-| How much of the plan is left, in the four levels the fill is drawn in.
-}
type Stage
    = Ample
    | Steady
    | Low
    | Critical


{-| Which level a car's fill is drawn in: quarters of the plan left, counted in whole laps so the boundaries land where the pit wall counts them.

An [`Overrun`](Motorsport-Analysis-Energy#Energy) never reaches this -- it has no fill to
colour.

-}
stageOf : Energy.Level -> Stage
stageOf level =
    let
        quarters =
            level.laps * 4
    in
    if quarters >= level.plan * 3 then
        Ample

    else if quarters >= level.plan * 2 then
        Steady

    else if quarters >= level.plan then
        Low

    else
        Critical


{-| The bar, filled to the share of the class's plan the car has left.

`Nothing` is a car this round's field does not hold: an empty cell keeps the row's
columns lined up and says nothing, which is what is known.

-}
bar : Maybe Energy -> Html msg
bar reading =
    case reading of
        Nothing ->
            div [ class "h-3" ] []

        Just Unreadable ->
            div
                [ class "h-3 grid place-items-center"
                , title noWindowTitle
                ]
                [ div [ class "w-3 h-px bg-muted-foreground" ] [] ]

        Just (Running level) ->
            track "bg-muted" [ fill (stageOf level) level, band level ] (runningTitle level)

        Just (Overrun level) ->
            track "bg-red-600/20" [] (overrunTitle level)

        Just (Spread spread) ->
            track "bg-muted" [ quartiles spread, middle spread ] (spreadTitle spread)


{-| The whole plan, drawn as the bar is. `trackClass` is the level the track itself
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

Twice the band, since the band is a middle distance reaching one way and the drawing is the two of them together -- which is the ± the tooltip states.

A band that runs off either end is cut at the end rather than drawn as a wider bar: the plan is the whole track, and the uncertainty lives inside it.

-}
band : Energy.Level -> Html msg
band level =
    let
        share =
            100 * toFloat (level.band * 2) / toFloat level.plan

        edge =
            100 * level.fraction - share / 2

        left =
            clampShare edge

        right =
            clampShare (edge + share)
    in
    div
        [ class "absolute top-0 h-full bg-foreground/25"
        , style "left" (percent left)
        , style "width" (percent (right - left))
        ]
        []


{-| The laps a class's middle half came in on, on the track its ninth decile fills.

The hue is the one a level's own band is drawn in, which is the same fact about the same runs.

It is drawn where a level's fill would be, because a cell with nothing in it is read as a car that has not started.

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

It is a pixel wide, so its own width comes off the far end of the track: a class whose middle stop and decile fall on the same lap would otherwise stand the mark past the end, where the track's own overflow cuts it away and the cell says nothing about the middle of its stops.

-}
middle : Energy.Stops -> Html msg
middle spread =
    div
        [ class "absolute top-0 h-full w-px bg-muted-foreground"
        , style "left" (percent (clampShare (across spread spread.median - 100 / width)))
        ]
        []


{-| How far along the track a lap of the class's ninth decile stands.

A class whose stopped runs had no pace lap in them has a decile of nothing to measure over, and its cell is drawn at the end of the track rather than at a NaN -- which `clampShare` cannot catch, both of its comparisons reading false against a NaN.

-}
across : Energy.Stops -> Int -> Float
across spread lap =
    if spread.ceiling <= 0 then
        0

    else
        100 * toFloat lap / toFloat spread.ceiling


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
    laps level.laps ++ " left of the class's " ++ planOf level ++ " (±" ++ laps level.band ++ ")" ++ reached level


overrunTitle : Energy.Level -> String
overrunTitle level =
    laps level.laps ++ " past the class's " ++ planOf level ++ reached level


{-| Where nine in ten of the class's stops came in by, said only where that is further than
its plan -- how far past the plan a car can be before its own class has hardly been there.
-}
reached : Energy.Level -> String
reached level =
    if level.ceiling > level.plan then
        " · " ++ nineInTen level.ceiling

    else
        ""


spreadTitle : Energy.Stops -> String
spreadTitle spread =
    "No plan here: half this class's stops fall between "
        ++ String.fromInt spread.low
        ++ " and "
        ++ laps spread.high
        ++ ", its middle stop on lap "
        ++ String.fromInt spread.median
        ++ ", "
        ++ nineInTen spread.ceiling


{-| The class's ninth decile, in a reader's words.

A decile is a rank and not a maximum: the class's longest run stands above it in all but the
rarest class, so it is not said as how far the class got.

-}
nineInTen : Int -> String
nineInTen by =
    "nine of its ten stops by lap " ++ String.fromInt by


planOf : Energy.Level -> String
planOf level =
    String.fromInt level.plan ++ "-lap plan"


laps : Int -> String
laps count =
    if count == 1 then
        "1 lap"

    else
        String.fromInt count ++ " laps"


{-| `Unreadable`, in a reader's words: the class has not stopped often enough to be read at
all.
-}
noWindowTitle : String
noWindowTitle =
    "No reading: this class has not stopped ten times with the field unheld"
