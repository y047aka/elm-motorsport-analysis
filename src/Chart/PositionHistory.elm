module Chart.PositionHistory exposing (view)

import Axis exposing (tickCount, tickSizeInner, tickSizeOuter)
import Css exposing (block, display)
import Css.Extra exposing (strokeWidth, svgPalette)
import Css.Global exposing (descendants, each)
import Css.Palette.Svg exposing (..)
import Data.Wec.Car as Wec
import Data.Wec.Class as Class
import Html.Styled exposing (Html)
import List.Extra as List
import Motorsport.Car as Motorsport
import Motorsport.Lap exposing (completedLapsAt)
import Motorsport.RaceControl as RaceControl
import Scale exposing (ContinuousScale)
import Svg.Styled as Svg exposing (Svg, fromUnstyled, g, polyline, svg, text, text_)
import Svg.Styled.Attributes exposing (css)
import TypedSvg.Styled.Attributes exposing (points, transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx exposing (height, width)
import TypedSvg.Types exposing (Paint(..), Transform(..))


type alias OrdersByLap =
    List { lapNumber : Int, order : List String }


w : Float
w =
    1600


h : Float
h =
    w * (9 / 16)


padding : Float
padding =
    20


paddingLeft : Float
paddingLeft =
    padding + 190


paddingVertical : Float
paddingVertical =
    padding + 30


xScale : OrdersByLap -> ContinuousScale Float
xScale ordersByLap =
    Scale.linear ( paddingLeft, w - padding ) ( 0, toFloat (List.length ordersByLap) )


yScale : List Wec.Car -> ContinuousScale Float
yScale cars =
    Scale.linear ( paddingVertical, h - paddingVertical ) ( 0, toFloat (List.length cars - 1) )


xAxis : OrdersByLap -> Svg msg
xAxis ordersByLap =
    let
        axis tag =
            fromUnstyled <|
                tag
                    [ tickCount <| (List.length ordersByLap // 10)
                    , tickSizeOuter 5
                    , tickSizeInner 5
                    ]
                    (xScale ordersByLap)
    in
    g
        [ css
            [ descendants
                [ Css.Global.typeSelector "text" [ svgPalette textOptional ]
                , each
                    [ Css.Global.typeSelector "line"
                    , Css.Global.typeSelector "path"
                    ]
                    [ strokeWidth 1
                    , svgPalette strokeAxis
                    ]
                ]
            ]
        ]
        [ g [ transform [ Translate 0 (paddingVertical - 20) ] ] [ axis Axis.top ]
        , g [ transform [ Translate 0 (h - paddingVertical + 20) ] ] [ axis Axis.bottom ]
        ]


view : { raceControl : RaceControl.Model, ordersByLap : OrdersByLap } -> Html msg
view { raceControl, ordersByLap } =
    let
        wecCars =
            List.map (summarize ordersByLap) raceControl.cars
    in
    svg
        [ width w
        , height h
        , viewBox 0 0 w h
        , css [ display block ]
        ]
        [ xAxis ordersByLap
        , g []
            (wecCars
                |> List.sortBy .startPosition
                |> List.map
                    (\car ->
                        history
                            { x = toFloat >> Scale.convert (xScale ordersByLap)
                            , y = toFloat >> Scale.convert (yScale wecCars)
                            , svgPalette = Class.toStrokePalette car.class
                            , label = String.join " " [ car.carNumber, car.team ]
                            }
                            (car |> (\c -> { c | positions = List.take (List.length <| completedLapsAt raceControl.raceClock car.laps) car.positions }))
                    )
            )
        ]


summarize : OrdersByLap -> Motorsport.Car -> Wec.Car
summarize ordersByLap { carNumber, class, group, team, manufacturer, laps } =
    { carNumber = carNumber
    , class = class
    , group = group
    , team = team
    , manufacturer = manufacturer
    , startPosition = Maybe.withDefault 0 <| getPositionAt { carNumber = carNumber, lapNumber = 1 } ordersByLap
    , positions =
        List.indexedMap
            (\index _ -> Maybe.withDefault 0 <| getPositionAt { carNumber = carNumber, lapNumber = index + 1 } ordersByLap)
            laps
    , laps = laps
    }


getPositionAt : { carNumber : String, lapNumber : Int } -> OrdersByLap -> Maybe Int
getPositionAt { carNumber, lapNumber } ordersByLap =
    ordersByLap
        |> List.find (.lapNumber >> (==) lapNumber)
        |> Maybe.andThen (.order >> List.findIndex ((==) carNumber))


history :
    { x : Int -> Float
    , y : Int -> Float
    , svgPalette : SvgPalette
    , label : String
    }
    -> Wec.Car
    -> Svg msg
history { x, y, svgPalette, label } { carNumber, startPosition, positions } =
    history_
        { heading =
            heading
                { x = x <| -50
                , y = y startPosition + 5
                }
                [ text label ]
        , polyline =
            (startPosition :: positions)
                |> List.indexedMap (\i position -> ( x i, y position ))
                |> polyline_ { svgPalette = svgPalette }
        , positionLabels =
            (startPosition :: positions)
                |> List.indexedMap (\i position -> ( x i, y position ))
                |> positionLabels { label = text carNumber }
        }


history_ : { heading : Svg msg, positionLabels : List (Svg msg), polyline : Svg msg } -> Svg msg
history_ options =
    g []
        [ options.heading
        , options.polyline

        -- , g [] options.positionLabels
        ]


heading : { x : Float, y : Float } -> List (Svg msg) -> Svg msg
heading { x, y } =
    text_ [ InPx.x x, InPx.y y ]


polyline_ : { svgPalette : SvgPalette } -> List ( Float, Float ) -> Svg msg
polyline_ options points_ =
    polyline [ css [ svgPalette options.svgPalette ], points points_ ] []


positionLabels : { label : Svg msg } -> List ( Float, Float ) -> List (Svg msg)
positionLabels { label } =
    List.map (\( x, y ) -> text_ [ InPx.x x, InPx.y y ] [ label ])
