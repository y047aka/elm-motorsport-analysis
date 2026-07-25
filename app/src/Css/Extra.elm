module Css.Extra exposing (strokeWidth, when)

import Css exposing (Style, batch, property)


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
