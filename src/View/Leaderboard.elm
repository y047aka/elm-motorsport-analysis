module View.Leaderboard exposing (view)

import Chart.Fragments exposing (dot, path)
import Css exposing (color, hex, px)
import Data.Leaderboard exposing (Leaderboard)
import Html.Styled as Html exposing (Html, span, text)
import Html.Styled.Attributes exposing (css)
import Motorsport.Clock exposing (Clock)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap(..))
import Motorsport.Lap exposing (Lap, LapStatus(..), lapStatus)
import Scale exposing (ContinuousScale)
import Svg.Styled exposing (Svg, g, rect, svg)
import Svg.Styled.Attributes as SvgAttributes exposing (fill)
import TypedSvg.Styled.Attributes exposing (viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx
import UI.SortableData exposing (State, customColumn, increasingOrDecreasingBy, intColumn, stringColumn, table, veryCustomColumn)


view : State -> Clock -> { fastestLapTime : Duration, slowestLapTime : Duration } -> (State -> msg) -> Float -> Leaderboard -> Html msg
view tableState raceClock analysis toMsg coefficient =
    let
        config =
            { toId = .carNumber
            , toMsg = toMsg
            , columns =
                [ intColumn { label = "Position", getter = .position }
                , stringColumn { label = "#", getter = .carNumber }
                , stringColumn { label = "Driver", getter = .driver }
                , intColumn { label = "Lap", getter = .lap }
                , customColumn
                    { label = "Gap"
                    , getter = .gap >> Gap.toString
                    , sorter = increasingOrDecreasingBy .position
                    }
                , veryCustomColumn
                    { label = "Gap"
                    , getter =
                        \{ gap } ->
                            case gap of
                                None ->
                                    text "-"

                                Seconds duration ->
                                    gap_ duration

                                Laps _ ->
                                    text "-"
                    , sorter = increasingOrDecreasingBy .position
                    }
                , veryCustomColumn
                    { label = "Time"
                    , getter =
                        \item ->
                            span
                                [ css
                                    [ color <|
                                        hex <|
                                            case lapStatus { time = analysis.fastestLapTime } item of
                                                Fastest ->
                                                    "#F0F"

                                                PersonalBest ->
                                                    "#0C0"

                                                Normal ->
                                                    "inherit"
                                    ]
                                ]
                                [ text <| Duration.toString item.time ]
                    , sorter = increasingOrDecreasingBy .time
                    }
                , veryCustomColumn
                    { label = "Time"
                    , getter = .history >> performance raceClock analysis coefficient
                    , sorter = increasingOrDecreasingBy .time
                    }
                , veryCustomColumn
                    { label = "Histogram"
                    , getter = .history >> histogram analysis coefficient
                    , sorter = increasingOrDecreasingBy .time
                    }
                ]
            }
    in
    table config tableState


w : Float
w =
    200


h : Float
h =
    20


padding : Float
padding =
    1


xScale : ( Int, Float ) -> ContinuousScale Float
xScale ( min, max ) =
    ( toFloat min, max ) |> Scale.linear ( padding, w - padding )


yScale : ( Float, Float ) -> ContinuousScale Float
yScale ( min, max ) =
    ( min, max ) |> Scale.linear ( h - padding, padding )


histogram : { fastestLapTime : Duration, slowestLapTime : Duration } -> Float -> List Lap -> Html msg
histogram { fastestLapTime, slowestLapTime } coefficient laps =
    let
        xScale_ =
            xScale ( fastestLapTime, min (toFloat fastestLapTime * coefficient) (toFloat slowestLapTime) )

        width lap =
            if isCurrentLap lap then
                3

            else
                1

        color lap =
            case
                ( isCurrentLap lap, lapStatus { time = fastestLapTime } { time = lap.time, best = lap.best } )
            of
                ( True, Fastest ) ->
                    "#F0F"

                ( True, PersonalBest ) ->
                    "#0C0"

                ( True, Normal ) ->
                    "#FC0"

                ( False, _ ) ->
                    "hsla(0, 0%, 50%, 0.5)"

        isCurrentLap { lap } =
            List.length laps == lap
    in
    svg [ viewBox 0 0 w h, SvgAttributes.css [ Css.width (px 200) ] ]
        [ histogram_
            { x = .time >> toFloat >> Scale.convert xScale_
            , y = always 0 >> Scale.convert (yScale ( 0, 0 ))
            , width = width
            , color = color
            }
            laps
        ]


histogram_ :
    { x : a -> Float, y : a -> Float, width : a -> Float, color : a -> String }
    -> List a
    -> Svg msg
histogram_ { x, y, width, color } laps =
    g [] <|
        List.map
            (\lap ->
                rect
                    [ InPx.x (x lap - 1)
                    , InPx.y (y lap - 10)
                    , InPx.width (width lap)
                    , InPx.height 20
                    , fill (color lap)
                    ]
                    []
            )
            laps


gap_ : Duration -> Html msg
gap_ time =
    svg [ viewBox 0 0 w h, SvgAttributes.css [ Css.width (px 200) ] ]
        [ rect
            [ InPx.x 0
            , InPx.y 0
            , InPx.width (time |> toFloat |> Scale.convert (xScale ( 0, 100000 )))
            , InPx.height 20
            , fill "#999"
            ]
            []
        ]


performance : Clock -> { a | fastestLapTime : Duration } -> Float -> List Lap -> Html msg
performance raceClock { fastestLapTime } coefficient laps =
    svg [ viewBox 0 0 w h, SvgAttributes.css [ Css.width (px 200) ] ]
        [ dotHistory
            { x = .elapsed >> toFloat >> Scale.convert (xScale ( 0, toFloat <| raceClock.elapsed ))
            , y = .time >> toFloat >> Scale.convert (yScale ( toFloat fastestLapTime * coefficient, toFloat fastestLapTime ))
            , color = "#999"
            }
            laps
        ]


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
