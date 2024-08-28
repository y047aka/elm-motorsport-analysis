module Motorsport.Chart.LapTimeChartsByDriver exposing (view)

import Axis exposing (tickCount, tickSizeInner, tickSizeOuter)
import Css exposing (Style, fill, hex, listStyle, none, property, zero)
import Css.Global exposing (descendants, each, typeSelector)
import Html.Styled exposing (Html, li, p, text, ul)
import Html.Styled.Attributes exposing (css)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.Fragments exposing (dot, path)
import Motorsport.Duration exposing (Duration)
import Motorsport.RaceControl as RaceControl
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg, fromUnstyled, g, svg)
import Svg.Styled.Attributes as Svg
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Types exposing (Transform(..))


w : Float
w =
    250


h : Float
h =
    100


padding : Float
padding =
    10


paddingLeft : Float
paddingLeft =
    padding + 25


paddingBottom : Float
paddingBottom =
    padding + 5


xScale : Int -> ContinuousScale Float
xScale lapTotal =
    Scale.linear ( paddingLeft, w - padding ) ( 0, toFloat lapTotal )


yScale : Duration -> ContinuousScale Float
yScale fastestLapTime =
    Scale.linear ( h - paddingBottom, padding ) ( toFloat fastestLapTime, toFloat fastestLapTime * 1.2 )


xAxis : Int -> Svg msg
xAxis lapTotal =
    g [ transform [ Translate 0 (h - paddingBottom) ], Svg.css axisStyles ]
        [ fromUnstyled <| Axis.bottom [ tickCount 5, tickSizeInner 4, tickSizeOuter 4 ] (xScale lapTotal) ]


yAxis : Duration -> Svg msg
yAxis fastestLapTime =
    g [ transform [ Translate paddingLeft 0 ], Svg.css axisStyles ]
        [ fromUnstyled <| Axis.left [ tickCount 2, tickSizeInner 3, tickSizeOuter 3 ] (yScale fastestLapTime) ]


axisStyles : List Style
axisStyles =
    [ descendants
        [ each [ typeSelector "line", typeSelector "path" ]
            [ property "stroke" "#999" ]
        , typeSelector "text"
            [ fill (hex "#999") ]
        ]
    ]


view : Analysis -> RaceControl.Model -> Html msg
view analysis { lapTotal, cars } =
    let
        fastestLapTime =
            analysis.fastestLapTime
    in
    ul
        [ css
            [ property "display" "grid"
            , property "grid-template-columns" "1fr 1fr 1fr 1fr"
            , property "grid-gap" "2rem"
            , Css.padding zero
            ]
        ]
        (List.map
            (\{ carNumber, laps } ->
                li [ css [ listStyle none ] ]
                    [ p [] [ text carNumber ]
                    , svg [ viewBox 0 0 w h ]
                        [ xAxis lapTotal
                        , yAxis fastestLapTime
                        , dotHistory
                            { x = .lap >> toFloat >> Scale.convert (xScale lapTotal)
                            , y = .time >> toFloat >> Scale.convert (yScale fastestLapTime)
                            , color = "#000"
                            }
                            laps
                        ]
                    ]
            )
            cars
        )


dotHistory : { x : a -> Float, y : a -> Float, color : String } -> List a -> Svg msg
dotHistory { x, y, color } laps =
    dotHistory_
        { dots =
            List.map
                (\lap ->
                    dot
                        { cx = x lap
                        , cy = y lap
                        , fillColor = color
                        }
                )
                laps
        , path =
            laps
                |> List.map (\item -> Just ( x item, y item ))
                |> path { strokeColor = color }
        }


dotHistory_ : { dots : List (Svg msg), path : Svg msg } -> Svg msg
dotHistory_ options =
    g []
        [ options.path
        , g [] options.dots
        ]
