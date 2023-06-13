module Chart.LapTimeChartsByDriver exposing (view)

import Axis exposing (tickCount, tickSizeInner, tickSizeOuter)
import Chart.Fragments exposing (dot, path)
import Css exposing (Style, fill, hex, listStyle, none, property, zero)
import Css.Global exposing (descendants, each, typeSelector)
import Data.F1.Analysis exposing (Analysis)
import Data.F1.Lap exposing (Lap, fastest)
import Html.Styled exposing (Html, li, p, text, ul)
import Html.Styled.Attributes exposing (css)
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


yScale : Lap -> ContinuousScale Float
yScale fastestLap =
    Scale.linear ( h - paddingBottom, padding ) ( fastestLap.time, fastestLap.time * 1.2 )


xAxis : Int -> Svg msg
xAxis lapTotal =
    g [ transform [ Translate 0 (h - paddingBottom) ], Svg.css axisStyles ]
        [ fromUnstyled <| Axis.bottom [ tickCount 5, tickSizeInner 4, tickSizeOuter 4 ] (xScale lapTotal) ]


yAxis : Lap -> Svg msg
yAxis fastestLap =
    g [ transform [ Translate paddingLeft 0 ], Svg.css axisStyles ]
        [ fromUnstyled <| Axis.left [ tickCount 2, tickSizeInner 3, tickSizeOuter 3 ] (yScale fastestLap) ]


axisStyles : List Style
axisStyles =
    [ descendants
        [ each [ typeSelector "line", typeSelector "path" ]
            [ property "stroke" "#999" ]
        , typeSelector "text"
            [ fill (hex "#999") ]
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
            (\{ carNumber, driver, laps } ->
                li [ css [ listStyle none ] ]
                    [ p [] [ text (carNumber ++ " " ++ driver.name) ]
                    , svg [ viewBox 0 0 w h ]
                        [ xAxis summary.lapTotal
                        , yAxis fastestLap
                        , dotHistory
                            { x = .lapCount >> toFloat >> Scale.convert (xScale summary.lapTotal)
                            , y = .time >> Scale.convert (yScale fastestLap)
                            , color = driver.teamColor
                            }
                            laps
                        ]
                    ]
            )
            raceHistories
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
