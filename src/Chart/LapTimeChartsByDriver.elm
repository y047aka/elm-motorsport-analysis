module Chart.LapTimeChartsByDriver exposing (view)

import Axis exposing (tickCount, tickSizeInner, tickSizeOuter)
import Css exposing (Style, hex, listStyle, none, property, zero)
import Css.Global exposing (descendants, each, typeSelector)
import Data.Analysis exposing (Analysis)
import Data.Lap exposing (Lap, fastest)
import Data.RaceSummary exposing (RaceSummary)
import Html.Styled exposing (Html, li, p, text, ul)
import Html.Styled.Attributes exposing (css)
import Path.Styled as Path
import Scale exposing (ContinuousScale)
import Shape
import Svg.Styled exposing (Svg, circle, fromUnstyled, g, svg)
import Svg.Styled.Attributes as Svg exposing (fill, stroke)
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Styled.Attributes.InPx exposing (cx, cy, r)
import TypedSvg.Types exposing (Transform(..))


w : Float
w =
    250


h : Float
h =
    100


padding : { top : Float, left : Float, bottom : Float, right : Float }
padding =
    { top = 20, left = 35, bottom = 15, right = 10 }


xScale : Int -> ContinuousScale Float
xScale lapTotal =
    Scale.linear ( padding.left, w - padding.right ) ( 0, toFloat lapTotal )


yScale : Lap -> ContinuousScale Float
yScale fastestLap =
    Scale.linear ( h - padding.bottom, padding.top ) ( fastestLap.time, fastestLap.time * 1.2 )


xAxis : Int -> Svg msg
xAxis lapTotal =
    g [ transform [ Translate 0 (h - padding.bottom) ], Svg.css axisStyles ]
        [ fromUnstyled <| Axis.bottom [ tickCount 5, tickSizeInner 4, tickSizeOuter 4 ] (xScale lapTotal) ]


yAxis : Lap -> Svg msg
yAxis fastestLap =
    g [ transform [ Translate padding.left 0 ], Svg.css axisStyles ]
        [ fromUnstyled <| Axis.left [ tickCount 2, tickSizeInner 3, tickSizeOuter 3 ] (yScale fastestLap) ]


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
        fastestLap =
            raceHistories
                |> List.filterMap (.laps >> fastest)
                |> fastest
                |> Maybe.withDefault (Lap 0 0 0)
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
            (\history ->
                li [ css [ listStyle none ] ]
                    [ p [] [ text (history.carNumber ++ " " ++ history.driver.name) ]
                    , lapTimeChart
                        { x = .lapCount >> toFloat >> Scale.convert (xScale summary.lapTotal)
                        , y = .time >> Scale.convert (yScale fastestLap)
                        , fastestLap = fastestLap
                        , color = history.driver.teamColor
                        }
                        summary
                        history.laps
                    ]
            )
            raceHistories
        )


lapTimeChart :
    { x : Lap -> Float
    , y : Lap -> Float
    , fastestLap : Lap
    , color : String
    }
    -> RaceSummary
    -> List Lap
    -> Html msg
lapTimeChart options { lapTotal } laps =
    let
        dot_ =
            dot { x = options.x, y = options.y, fillColor = options.color }
    in
    svg [ viewBox 0 0 w h ]
        [ xAxis lapTotal
        , yAxis options.fastestLap
        , path { x = options.x, y = options.y, strokeColor = options.color } laps
        , g [] (List.map dot_ laps)
        ]


dot : { x : a -> Float, y : a -> Float, fillColor : String } -> a -> Svg msg
dot options item =
    g []
        [ circle
            [ cx (options.x item)
            , cy (options.y item)
            , r 1.5
            , fill options.fillColor
            ]
            []
        ]


path : { x : a -> Float, y : a -> Float, strokeColor : String } -> List a -> Svg msg
path { x, y, strokeColor } items =
    items
        |> List.map (\item -> Just ( x item, y item ))
        |> Shape.line Shape.linearCurve
        |> (\path_ -> Path.element path_ [ fill "none", stroke strokeColor ])
