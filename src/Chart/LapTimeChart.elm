module Chart.LapTimeChart exposing (view)

import Axis
import Css exposing (property)
import Data.Analysis exposing (Analysis, History)
import Data.Lap exposing (Lap, fastest)
import Html.Styled exposing (Html, fromUnstyled, text)
import Path
import Scale exposing (ContinuousScale)
import Shape
import Svg.Styled exposing (Svg, circle, g, svg, text_)
import Svg.Styled.Attributes exposing (class, css, fill)
import TypedSvg.Attributes exposing (style, transform)
import TypedSvg.Styled.Attributes exposing (viewBox)
import TypedSvg.Styled.Attributes.InPx exposing (cx, cy, r, x, y)
import TypedSvg.Types exposing (Transform(..))


w : Float
w =
    1000


h : Float
h =
    400


padding : { top : Float, right : Float, bottom : Float, left : Float }
padding =
    { top = 20, right = 20, bottom = 30, left = 60 }


xScale : Int -> ContinuousScale Float
xScale lapTotal =
    Scale.linear ( padding.left, w - padding.right ) ( 0, toFloat lapTotal )


yScale : Lap -> ContinuousScale Float
yScale fastestLap =
    Scale.linear ( h - padding.bottom, padding.top ) ( fastestLap.time, fastestLap.time * 1.2 )


xAxis : Int -> Svg msg
xAxis lapTotal =
    g [ class "x-axis", Svg.Styled.Attributes.fromUnstyled <| transform [ Translate 0 (h - padding.bottom) ] ]
        [ fromUnstyled <| Axis.bottom [] (xScale lapTotal) ]


yAxis : Lap -> Svg msg
yAxis fastestLap =
    g [ class "y-axis", Svg.Styled.Attributes.fromUnstyled <| transform [ Translate padding.left 0 ] ]
        [ fromUnstyled <| Axis.left [] (yScale fastestLap) ]


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
        , viewLapHistories
            { x = .lapCount >> toFloat >> Scale.convert (xScale lapTotal)
            , y = .time >> Scale.convert (yScale fastestLap)
            }
            raceHistories
        ]


viewLapHistories : { x : Lap -> Float, y : Lap -> Float } -> List History -> Svg msg
viewLapHistories options histories =
    g [] <|
        List.map
            (\history ->
                viewLapHistory
                    { x = options.x
                    , y = options.y
                    , dotLabel = .lapCount >> String.fromInt
                    , color = history.driver.teamColor
                    }
                    history.laps
            )
            histories


viewLapHistory :
    { x : a -> Float
    , y : a -> Float
    , dotLabel : a -> String
    , color : String
    }
    -> List a
    -> Svg msg
viewLapHistory options laps =
    g
        [ Svg.Styled.Attributes.class "history" ]
        [ drawCurve
            { x = options.x
            , y = options.y
            , strokeColor = options.color
            }
            laps
        , g [] <|
            List.map
                (dotWithLabel
                    { x = options.x
                    , y = options.y
                    , label = options.dotLabel
                    , fillColor = options.color
                    }
                )
                laps
        ]


dotWithLabel : { x : a -> Float, y : a -> Float, label : a -> String, fillColor : String } -> a -> Svg msg
dotWithLabel options item =
    g [ class "lap" ]
        [ circle
            [ cx (options.x item)
            , cy (options.y item)
            , r 2
            , fill options.fillColor
            ]
            []
        , text_ [ x (options.x item), y (options.y item) ] [ text <| options.label item ]
        ]


drawCurve : { x : a -> Float, y : a -> Float, strokeColor : String } -> List a -> Svg msg
drawCurve { x, y, strokeColor } items =
    items
        |> List.map (\item -> Just ( x item, y item ))
        |> Shape.line Shape.linearCurve
        |> (\path -> Path.element path [ style ("stroke: " ++ strokeColor) ])
        |> fromUnstyled
