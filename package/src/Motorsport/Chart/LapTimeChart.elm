module Motorsport.Chart.LapTimeChart exposing (view)

import Axis
import Css exposing (Style, fill, hex, property)
import Css.Global exposing (descendants, each, typeSelector)
import Html.Styled exposing (Html)
import List.NonEmpty as NonEmpty
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.Fragments exposing (dotWithLabel, path)
import Motorsport.Duration exposing (Duration)
import Motorsport.RaceControl as RaceControl
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg, fromUnstyled, g, svg, text)
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


yScale : Duration -> ContinuousScale Float
yScale fastestLapTime =
    Scale.linear ( h - paddingBottom, padding ) ( toFloat fastestLapTime, toFloat fastestLapTime * 1.2 )


xAxis : Int -> Svg msg
xAxis lapTotal =
    g [ transform [ Translate 0 (h - paddingBottom) ], css axisStyles ]
        [ fromUnstyled <| Axis.bottom [] (xScale lapTotal) ]


yAxis : Duration -> Svg msg
yAxis fastestLapTime =
    g [ transform [ Translate paddingLeft 0 ], css axisStyles ]
        [ fromUnstyled <| Axis.left [] (yScale fastestLapTime) ]


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
    svg [ viewBox 0 0 w h ]
        [ xAxis lapTotal
        , yAxis fastestLapTime
        , g [] <|
            (cars
                |> NonEmpty.toList
                |> List.map
                    (\{ laps } ->
                        dotHistory
                            { x = .lap >> toFloat >> Scale.convert (xScale lapTotal)
                            , y = .time >> toFloat >> Scale.convert (yScale fastestLapTime)
                            , color = "#000"
                            , dotLabel = .lap >> String.fromInt
                            }
                            laps
                    )
            )
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
