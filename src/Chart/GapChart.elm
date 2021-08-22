module Chart.GapChart exposing (view)

import Axis
import Chart.Fragments exposing (dotWithLabel, path)
import Css exposing (Style, fill, hex, property)
import Css.Global exposing (descendants, each, typeSelector)
import Data.Analysis exposing (Analysis)
import Data.Lap exposing (Lap, fastest)
import Html.Styled exposing (Html, text)
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg, fromUnstyled, g, svg)
import Svg.Styled.Attributes exposing (css)
import TypedSvg.Styled.Attributes exposing (transform, viewBox)
import TypedSvg.Types exposing (Transform(..))


w : Float
w =
    1000


h : Float
h =
    400


padding : Float
padding =
    20


paddingLeft : Float
paddingLeft =
    padding + 40


paddingBottom : Float
paddingBottom =
    padding + 10


xScale : Int -> ContinuousScale Float
xScale lapTotal =
    Scale.linear ( paddingLeft, w - padding ) ( 0, toFloat lapTotal )


yScale : Lap -> ContinuousScale Float
yScale fastestLap =
    Scale.linear ( h - paddingBottom, padding ) ( fastestLap.time * 25, 0 )


xAxis : Int -> Svg msg
xAxis lapTotal =
    g [ transform [ Translate 0 (h - paddingBottom) ], css axisStyles ]
        [ fromUnstyled <| Axis.bottom [] (xScale lapTotal) ]


yAxis : Lap -> Svg msg
yAxis fastestLap =
    g [ transform [ Translate paddingLeft 0 ], css axisStyles ]
        [ fromUnstyled <| Axis.left [] (yScale fastestLap) ]


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
