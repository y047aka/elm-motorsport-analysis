module Chart.GapChart exposing (view)

import Axis
import Css exposing (Style, block, cursor, default, display, hex, hover, none, property)
import Css.Global exposing (children, descendants, each, typeSelector)
import Data.Analysis exposing (Analysis, History)
import Data.Lap exposing (Lap, fastest)
import Html.Styled exposing (Html, text)
import Path.Styled as Path
import Scale exposing (ContinuousScale)
import Shape
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, svg, text_)
import Svg.Styled.Attributes exposing (css, fill, stroke)
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx exposing (cx, cy, r, x, y)
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
            dotHistories
                { x = .lapCount >> toFloat >> Scale.convert (xScale lapTotal)
                , y = (\{ lapCount, elapsed } -> elapsed - (toFloat lapCount * fastestLap.time * 1.02)) >> Scale.convert (yScale fastestLap)
                , dotLabel = .lapCount >> String.fromInt
                }
                raceHistories
        ]


dotHistories : { x : Lap -> Float, y : Lap -> Float, dotLabel : Lap -> String } -> List History -> List (Svg msg)
dotHistories { x, y, dotLabel } histories =
    List.map
        (\{ driver, laps } ->
            dotHistory
                { dots =
                    List.map
                        (\lap ->
                            dotWithLabel
                                { x = x lap
                                , y = y lap
                                , fillColor = driver.teamColor
                                }
                                [ text (dotLabel lap) ]
                        )
                        laps
                , path =
                    laps
                        |> List.map (\item -> Just ( x item, y item ))
                        |> path { strokeColor = driver.teamColor }
                }
        )
        histories


dotHistory : { dots : List (Svg msg), path : Svg msg } -> Svg msg
dotHistory options =
    g []
        [ options.path
        , g [] options.dots
        ]


dotWithLabel : { x : Float, y : Float, fillColor : String } -> List (Svg msg) -> Svg msg
dotWithLabel { x, y, fillColor } label =
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
        [ circle
            [ cx x
            , cy y
            , r 2
            , fill fillColor
            , stroke "#fff"
            ]
            []
        , text_ [ InPx.x x, InPx.y y ] label
        ]


path : { strokeColor : String } -> List (Maybe ( Float, Float )) -> Svg msg
path { strokeColor } items =
    items
        |> Shape.line Shape.linearCurve
        |> (\path_ -> Path.element path_ [ fill "none", stroke strokeColor ])
