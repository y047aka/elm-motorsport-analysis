module Css.Extra exposing (strokeWidth, svgPalette, when)

import Css exposing (Style, batch, property)
import Css.Color exposing (Color(..))
import Css.Palette.Svg exposing (SvgPalette)


none : Style
none =
    batch []


when : Bool -> Style -> Style
when condition style =
    if condition then
        style

    else
        none


strokeWidth : Float -> Style
strokeWidth w =
    property "stroke-width" (String.fromFloat w)


svgPalette : SvgPalette -> Style
svgPalette p =
    batch
        [ fill p.fill
        , stroke p.stroke
        ]


backgroundColor : Color -> Style
backgroundColor c =
    case c of
        ColorValue c_ ->
            Css.backgroundColor c_

        CurrentColor ->
            Css.backgroundColor Css.currentColor

        Transparent ->
            Css.backgroundColor Css.transparent


color : Color -> Style
color c =
    case c of
        ColorValue c_ ->
            Css.color c_

        CurrentColor ->
            Css.color Css.currentColor

        Transparent ->
            Css.color Css.transparent


borderColor : Color -> Style
borderColor c =
    case c of
        ColorValue c_ ->
            Css.borderColor c_

        CurrentColor ->
            Css.borderColor Css.currentColor

        Transparent ->
            Css.borderColor Css.transparent


fill : Color -> Style
fill c =
    case c of
        ColorValue c_ ->
            Css.fill c_

        CurrentColor ->
            Css.fill Css.currentColor

        Transparent ->
            Css.fill Css.transparent


stroke : Color -> Style
stroke c =
    let
        stroke_ =
            .value >> Css.property "stroke"
    in
    case c of
        ColorValue c_ ->
            stroke_ c_

        CurrentColor ->
            stroke_ Css.currentColor

        Transparent ->
            stroke_ Css.transparent
