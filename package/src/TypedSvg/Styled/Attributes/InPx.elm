module TypedSvg.Styled.Attributes.InPx exposing (cx, cy, height, r, width, x, y)

import Svg.Styled exposing (Attribute)
import Svg.Styled.Attributes as Attributes
import TypedSvg.Types exposing (px)
import TypedSvg.TypesToStrings exposing (lengthToString)


cx : Float -> Attribute msg
cx value =
    Attributes.cx <| lengthToString (px value)


cy : Float -> Attribute msg
cy value =
    Attributes.cy <| lengthToString (px value)


height : Float -> Attribute msg
height value =
    Attributes.height <| lengthToString (px value)


r : Float -> Attribute msg
r value =
    Attributes.r <| lengthToString (px value)


width : Float -> Attribute msg
width value =
    Attributes.width <| lengthToString (px value)


x : Float -> Attribute msg
x value =
    Attributes.x <| lengthToString (px value)


y : Float -> Attribute msg
y value =
    Attributes.y <| lengthToString (px value)
