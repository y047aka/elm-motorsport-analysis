module Motorsport.Chart.LapTimeChart exposing (view)

import Axis
import Css exposing (Style, fill, hex, property)
import Css.Global exposing (descendants, each, typeSelector)
import Html.Styled exposing (Html)
import Motorsport.Chart.Fragments exposing (dotWithLabel, path)
import Motorsport.Duration exposing (Duration)
import Motorsport.RaceControl as RaceControl
import Motorsport.RunningOrder as RunningOrder
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


xContinuousScale : Int -> ContinuousScale Float
xContinuousScale lapTotal =
    Scale.linear ( paddingLeft, w - padding ) ( 0, toFloat lapTotal )


yContinuousScale : Duration -> ContinuousScale Float
yContinuousScale fastestLapTime =
    Scale.linear ( h - paddingBottom, padding ) ( toFloat fastestLapTime, toFloat fastestLapTime * 1.2 )


xAxis : ContinuousScale Float -> Svg msg
xAxis xScale =
    g [ transform [ Translate 0 (h - paddingBottom) ], css axisStyles ]
        [ fromUnstyled <| Axis.bottom [] xScale ]


yAxis : ContinuousScale Float -> Svg msg
yAxis yScale =
    g [ transform [ Translate paddingLeft 0 ], css axisStyles ]
        [ fromUnstyled <| Axis.left [] yScale ]


axisStyles : List Style
axisStyles =
    [ descendants
        [ each [ typeSelector "line", typeSelector "path" ]
            [ property "stroke" "#999" ]
        , typeSelector "text"
            [ fill (hex "#999") ]
        ]
    ]


view : { a | fastestLapTime : Duration } -> RaceControl.Model -> Html msg
view reference { lapTotal, cars } =
    let
        fastestLapTime =
            reference.fastestLapTime

        xScale =
            xContinuousScale lapTotal

        yScale =
            yContinuousScale fastestLapTime
    in
    svg [ viewBox 0 0 w h ]
        [ xAxis xScale
        , yAxis yScale
        , g [] <|
            (cars
                |> RunningOrder.toList
                |> List.map
                    (\{ laps } ->
                        dotHistory
                            { x = .lap >> toFloat >> Scale.convert xScale
                            , y = .time >> toFloat >> Scale.convert yScale
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
