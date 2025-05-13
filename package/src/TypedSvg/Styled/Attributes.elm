module TypedSvg.Styled.Attributes exposing
    ( cx, cy, fill, fontSize
    , height
    , points, r
    , stroke, strokeWidth, transform
    , viewBox, width, x, x1, x2, y, y1, y2
    )

{-|

@docs accelerate, accentHeight, accumulate, additive, alignmentBaseline, allowReorder, alphabetic, amplitude, animateTransformType, animationValues, arabicForm, ascent, attributeName, attributeType, autoReverse, baseProfile, baselineShift, bbox, begin, by, calcMode, capHeight, class, clip, clipPath, clipPathUnits, clipRule, color, colorInterpolation, colorProfile, colorRendering, contentScriptType, contentStyleType, contentType, cursor, cx, cy, d, decelerate, descent, direction, display, dominantBaseline, dur, dx, dy, enableBackground, end, exponent, externalResourcesRequired, fill, fillOpacity, fillRule, filter, fontFamily, fontSize, fontSizeAdjust
@docs fontStretch, fontStyle, fontVariant, fontWeight, format, from, from2, from3, fx, fy, g1, g2, glyphName, glyphOrientationHorizontal, glyphOrientationVertical, glyphRef, gradientTransform, gradientUnits, hanging, height, horizAdvX, horizOriginX, horizOriginY, href, id, ideographic, imageRendering, intercept, k, kerning, keySplines, keyTimes, lang, lengthAdjust, letterSpacing, lightingColor, local, markerEnd, markerHeight, markerMid, markerStart, markerUnits, markerWidth, mask, maskContentUnits, maskUnits, max, media
@docs method, min, name, noFill, offset, opacity, orient, orientation, origin, overflow, overlinePosition, overlineThickness, panose1, path, pathLength, patternContentUnits, patternTransform, patternUnits, pointOrder, pointerEvents, points, preserveAspectRatio, primitiveUnits, r, refX, refY, renderingIntent, repeatCount, repeatDur, requiredExtensions, requiredFeatures, restart, rotate, rx, ry, shapeRendering, slope, spacing, specularConstant, specularExponent, speed, spreadMethod, startOffset
@docs stdDeviation, stemh, stemv, stitchTiles, stopColor, stopOpacity, strikethroughPosition, strikethroughThickness, string, stroke, strokeDasharray, strokeDashoffset, strokeLinecap, strokeLinejoin, strokeMiterlimit, strokeOpacity, strokeWidth, style, systemLanguage, tableValues, target, textAnchor, textDecoration, textLength, textRendering, title, to, to2, to3, transform, u1, u2, underlinePosition, underlineThickness, unicode, unicodeBidi, unicodeRange, unitsPerEm, vAlphabetic, vHanging, vIdeographic
@docs vMathematical, version, vertAdvY, vertOriginX, vertOriginY, viewBox, viewTarget, visibility, width, widths, wordSpacing, writingMode, x, x1, x2, xChannelSelector, xHeight, xlinkActuate, xlinkArcrole, xlinkHref, xlinkRole, xlinkShow, xlinkTitle, xlinkType, xmlBase, xmlLang, xmlSpace, y, y1, y2, yChannelSelector, zoomAndPan

-}

import Svg.Styled exposing (Attribute)
import Svg.Styled.Attributes as Attributes
import TypedSvg.Types exposing (Length, Paint, Transform)
import TypedSvg.TypesToStrings exposing (lengthToString, paintToString, transformToString)


cx : Length -> Attribute msg
cx length =
    Attributes.cx <| lengthToString length


cy : Length -> Attribute msg
cy length =
    Attributes.cy <| lengthToString length


fill : Paint -> Attribute msg
fill =
    Attributes.fill << paintToString


fontSize : Length -> Attribute msg
fontSize length =
    Attributes.fontSize <| lengthToString length


height : Length -> Attribute msg
height length =
    Attributes.height <| lengthToString length


points : List ( Float, Float ) -> Attribute msg
points pts =
    let
        pointToString ( xx, yy ) =
            String.fromFloat xx ++ ", " ++ String.fromFloat yy
    in
    Attributes.points <| String.join " " (List.map pointToString pts)


r : Length -> Attribute msg
r length =
    Attributes.r <| lengthToString length


stroke : Paint -> Attribute msg
stroke =
    Attributes.stroke << paintToString


strokeWidth : Length -> Attribute msg
strokeWidth length =
    Attributes.strokeWidth <| lengthToString length


transform : List Transform -> Attribute msg
transform transforms =
    Attributes.transform <| String.join " " (List.map transformToString transforms)


viewBox : Float -> Float -> Float -> Float -> Attribute a
viewBox minX minY vWidth vHeight =
    [ minX, minY, vWidth, vHeight ]
        |> List.map String.fromFloat
        |> String.join " "
        |> Attributes.viewBox


x : Length -> Attribute msg
x length =
    Attributes.x <| lengthToString length


x1 : Length -> Attribute msg
x1 position =
    Attributes.x1 <| lengthToString position


x2 : Length -> Attribute msg
x2 position =
    Attributes.x2 <| lengthToString position


y : Length -> Attribute msg
y length =
    Attributes.y <| lengthToString length


y1 : Length -> Attribute msg
y1 position =
    Attributes.y1 <| lengthToString position


y2 : Length -> Attribute msg
y2 position =
    Attributes.y2 <| lengthToString position


width : Length -> Attribute msg
width length =
    Attributes.width <| lengthToString length
