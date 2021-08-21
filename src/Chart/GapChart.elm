module Chart.GapChart exposing (view)

import Axis
import Css exposing (Style, block, cursor, default, display, hex, hover, none, property)
import Css.Global exposing (children, descendants, each, typeSelector)
import Data.Analysis exposing (Analysis)
import Data.Lap exposing (Lap, fastest)
import Html.Styled exposing (Html, text)
import Path.Styled as Path
import Scale exposing (ContinuousScale)
import Shape
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, svg, text_)
import Svg.Styled.Attributes exposing (css, fill, stroke)
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx exposing (r)
import TypedSvg.Types exposing (Transform(..))


w : Float
w =
    1000


h : Float
h =
    400


padding : { top : Float, left : Float, bottom : Float, right : Float }
padding =
    { top = 20, left = 60, bottom = 30, right = 20 }


xScale : Int -> ContinuousScale Float
xScale lapTotal =
    Scale.linear ( padding.left, w - padding.right ) ( 0, toFloat lapTotal )


yScale : Lap -> ContinuousScale Float
yScale fastestLap =
    Scale.linear ( h - padding.bottom, padding.top ) ( fastestLap.time * 25, 0 )


xAxis : Int -> Svg msg
xAxis lapTotal =
    g [ transform [ Translate 0 (h - padding.bottom) ], css axisStyles ]
        [ fromUnstyled <| Axis.bottom [] (xScale lapTotal) ]


yAxis : Lap -> Svg msg
yAxis fastestLap =
    g [ transform [ Translate padding.left 0 ], css axisStyles ]
        [ fromUnstyled <| Axis.left [] (yScale fastestLap) ]


axisStyles : List Style
axisStyles =
    [ descendants
        [ each [ typeSelector "line", typeSelector "path" ]
            [ property "stroke" "#999" ]
        , typeSelector "text"
            [ Css.fill (hex "#999") ]
        ]
    ]


view : Analysis -> Html msg
view { summary, raceHistories } =
    let
        lapTotal =
            summary.lapTotal

        fastestLap =
            raceHistories
                |> List.filterMap (.laps >> fastest)
                |> fastest
                |> Maybe.withDefault (Lap 0 0 0)
    in
    svg [ viewBox 0 0 w h ]
        [ xAxis lapTotal
        , yAxis fastestLap
        , g [] <|
            List.map
                (\{ driver, laps } ->
                    dotHistory
                        { x = .lapCount >> toFloat >> Scale.convert (xScale lapTotal)
                        , y = (\{ lapCount, elapsed } -> elapsed - (toFloat lapCount * fastestLap.time * 1.02)) >> Scale.convert (yScale fastestLap)
                        , color = driver.teamColor
                        , dotLabel = .lapCount >> String.fromInt
                        }
                        laps
                )
                raceHistories
        ]


dotHistory :
    { x : a -> Float
    , y : a -> Float
    , color : String
    , dotLabel : a -> String
    }
    -> List a
    -> Svg msg
dotHistory { x, y, color, dotLabel } items =
    dotHistory_
        { dots =
            List.map
                (\item ->
                    dotWithLabel
                        { cx = x item
                        , cy = y item
                        , fillColor = color
                        }
                        [ text (dotLabel item) ]
                )
                items
        , path =
            items
                |> List.map (\item -> Just ( x item, y item ))
                |> path { strokeColor = color }
        }


dotHistory_ : { dots : List (Svg msg), path : Svg msg } -> Svg msg
dotHistory_ options =
    g []
        [ options.path
        , g [] options.dots
        ]


dotWithLabel : { cx : Float, cy : Float, fillColor : String } -> List (Svg msg) -> Svg msg
dotWithLabel options label =
    g
        [ css
            [ children
                [ typeSelector "text"
                    [ display none, cursor default ]
                ]
            , hover
                [ children
                    [ typeSelector "text"
                        [ display block ]
                    ]
                ]
            ]
        ]
        [ dot options
        , text_ [ InPx.x options.cx, InPx.y options.cy ] label
        ]


dot : { cx : Float, cy : Float, fillColor : String } -> Svg msg
dot { cx, cy, fillColor } =
    circle
        [ InPx.cx cx
        , InPx.cy cy
        , r 2
        , fill fillColor
        , stroke "#fff"
        ]
        []


path : { strokeColor : String } -> List (Maybe ( Float, Float )) -> Svg msg
path { strokeColor } items =
    items
        |> Shape.line Shape.linearCurve
        |> (\path_ -> Path.element path_ [ fill "none", stroke strokeColor ])
