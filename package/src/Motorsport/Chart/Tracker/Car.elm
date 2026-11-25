module Motorsport.Chart.Tracker.Car exposing (marker, label)

{-| A car as both flat trackers mark it: a dot in its class's colour, shrinking and fading down the class, and its number set beside it.

@docs marker, label

-}

import Svg exposing (Svg, circle, text, text_)
import Svg.Attributes exposing (dominantBaseline, fill, style, textAnchor)
import TypedSvg.Attributes as Attributes exposing (fontSize)
import TypedSvg.Types exposing (px)


marker : Float -> Int -> String -> Svg msg
marker size positionInClass classColorValue =
    let
        scaleFactor =
            max 0.4 (1 - (toFloat positionInClass * 0.1))

        carSize =
            size * scaleFactor

        saturation =
            if positionInClass <= 3 then
                "100%"

            else
                "50%"
    in
    circle
        [ Attributes.cx (px 0)
        , Attributes.cy (px 0)
        , Attributes.r (px carSize)
        , fill classColorValue
        , style ("filter: saturate(" ++ saturation ++ ");")
        ]
        []


label : Float -> Int -> { x : Float, y : Float } -> { carNumber : String } -> Svg msg
label labelFontSize positionInClass { x, y } { carNumber } =
    let
        scaleFactor =
            max 0.75 (1 - (toFloat positionInClass * 0.02))
    in
    text_
        [ Attributes.x (px x)
        , Attributes.y (px y)
        , fontSize (px (labelFontSize * scaleFactor))
        , textAnchor "middle"
        , dominantBaseline "central"
        , fill "oklch(1 0 0 / 0.7)"
        ]
        [ text carNumber ]
