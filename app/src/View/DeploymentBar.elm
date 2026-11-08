module View.DeploymentBar exposing (bar, width)

{-| The standings' Deploy column: how much of its lap a car is putting down at
the end of the straight, against what its class did at the same pace.

The bar runs out of a centre both ways, because the reading is a difference: a car
richer than its class fills right, a leaner one left. Which side is which is the
whole of the judgement this column makes about a car, so neither side is coloured
as the good one -- the fill is the column's own colour whichever way it falls, and
the centre line is what says which way that is.

A bar is drawn only where there is a reading to draw: `Motorsport.Analysis.Deployment`
holds back a mean that stands inside its own uncertainty, and this says which of
its reasons it was, rather than drawing a short bar for a car it knows nothing
about.

@docs bar, width

-}

import Html exposing (Html, div)
import Html.Attributes exposing (class, style, title)
import Motorsport.Analysis.Deployment as Deployment exposing (Deployment(..), Shortfall(..))
import Motorsport.Speed as Speed exposing (Speed)


{-| How wide the column is, in pixels -- the track `columnSpec` gives it.
-}
width : Float
width =
    64


{-| The bar, drawn against the width of the class's own spread. `Nothing` for that
spread is a class with too few readable cars to have one, which leaves a reading
with no scale to be measured on: the centre is drawn and nothing is filled, since a
fill without a scale is a shape with no meaning.

`Nothing` for the reading itself is a car this round's field does not hold at all,
which is not a fact worth a tooltip: an empty cell keeps the row's columns lined up
and says nothing, which is what is known.

-}
bar : Maybe Deployment -> Maybe Speed -> Html msg
bar reading scale =
    case reading of
        Nothing ->
            div [ class "h-3" ] []

        Just (Deployment.Unreadable shortfall) ->
            div
                [ class "h-3 grid place-items-center text-[10px] leading-none text-muted-foreground"
                , title (reasonOf shortfall)
                ]
                [ div [ class "w-3 h-px bg-muted-foreground" ] [] ]

        Just (Deployment.Measured { residual, uncertainty, laps }) ->
            let
                centre =
                    div [ class "absolute top-0 h-full w-px bg-border", style "left" "50%" ] []
            in
            div
                [ class "relative h-3 rounded-[2px] bg-muted overflow-hidden"
                , title (readingOf residual uncertainty laps)
                ]
                (case scale of
                    Nothing ->
                        [ centre ]

                    Just field ->
                        [ centre, fill residual field ]
                )


{-| The fill, from the centre to the side the difference fell on.

The scale is twice the class's own spread, so a car at the top or bottom of its
class lands at the end of the bar and the middle of the class is a short stub
beside the centre: the bar is drawn on the width the class actually covers, and not
on a tolerance invented here.

-}
fill : Speed -> Speed -> Html msg
fill residual scale =
    let
        domain =
            toFloat (Speed.toTenths scale) * 2

        share =
            if domain > 0 then
                toFloat (Speed.toTenths (Speed.magnitude residual)) / domain

            else
                0

        length =
            Basics.clamp 0 0.5 share * 100

        left =
            if Speed.toTenths residual >= 0 then
                50

            else
                50 - length
    in
    div
        [ class "absolute top-0 h-full bg-primary/80"
        , style "left" (percent left)
        , style "width" (percent length)
        ]
        []


percent : Float -> String
percent value =
    String.fromFloat value ++ "%"


readingOf : Speed -> Speed -> Int -> String
readingOf residual uncertainty laps =
    Speed.toSignedString residual
        ++ " km/h at the trap against the class at the same pace, from "
        ++ String.fromInt laps
        ++ " laps (±"
        ++ Speed.toString uncertainty
        ++ ")"


reasonOf : Shortfall -> String
reasonOf shortfall =
    case shortfall of
        NoReading ->
            "No lap yet that was timed, measured at the trap, and run at pace"

        OneReading ->
            "One lap measured, which says nothing about a car: a single value has no spread to be judged against"

        Unresolved uncertainty ->
            "Its own mean, inside its own uncertainty of ±"
                ++ Speed.toString uncertainty
                ++ " km/h"

        NoFieldReading ->
            "Too few cars in the class readably measured to set a scale"
