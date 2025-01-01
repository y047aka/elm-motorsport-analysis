module Motorsport.Chart.Fragments exposing (dot, dotWithLabel, path)

import Css exposing (block, cursor, default, display, hover, none)
import Css.Global exposing (children, typeSelector)
import Path.Styled as Path
import Shape
import Svg.Styled exposing (Svg, circle, g, text_)
import Svg.Styled.Attributes exposing (css, fill, stroke)
import TypedSvg.Styled.Attributes.InPx as InPx exposing (r, x, y)


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
        , text_ [ x options.cx, y options.cy ] label
        ]


path : { strokeColor : String } -> List (Maybe ( Float, Float )) -> Svg msg
path { strokeColor } items =
    items
        |> Shape.line Shape.linearCurve
        |> (\path_ -> Path.element path_ [ fill "none", stroke strokeColor ])
