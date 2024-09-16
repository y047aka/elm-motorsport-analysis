module Motorsport.Chart.PositionHistory exposing (view)

import Axis exposing (tickCount, tickSizeInner, tickSizeOuter)
import Css exposing (block, display, fill, hsla)
import Css.Extra exposing (strokeWidth, svgPalette)
import Css.Global exposing (descendants, each)
import Css.Palette.Svg exposing (..)
import Html.Styled exposing (Html)
import List.Extra as List
import Motorsport.Car exposing (Car)
import Motorsport.Class as Class
import Motorsport.Lap exposing (completedLapsAt)
import Motorsport.RaceControl as RaceControl
import Scale exposing (ContinuousScale)
import Svg.Styled as Svg exposing (Svg, fromUnstyled, g, polyline, svg, text, text_)
import Svg.Styled.Attributes exposing (css)
import TypedSvg.Styled.Attributes exposing (points, transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx exposing (height, width)
import TypedSvg.Types exposing (Paint(..), Transform(..))


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


xScale : Int -> ContinuousScale Float
xScale lapTotal =
    Scale.linear ( paddingLeft, w - padding ) ( 0, toFloat lapTotal )


yScale : List Car -> ContinuousScale Float
yScale cars =
    Scale.linear ( paddingVertical, h - paddingVertical ) ( 0, toFloat (List.length cars - 1) )


xAxis : Int -> Svg msg
xAxis lapTotal =
    let
        axis tag =
            fromUnstyled <|
                tag
                    [ tickCount <| (lapTotal // 10)
                    , tickSizeOuter 5
                    , tickSizeInner 5
                    ]
                    (xScale lapTotal)
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


view : RaceControl.Model -> Html msg
view { raceClock, lapTotal, cars } =
    svg
        [ width w
        , height h
        , viewBox 0 0 w h
        , css [ display block ]
        ]
        [ xAxis lapTotal
        , g []
            (cars
                |> List.sortBy .startPosition
                |> List.map
                    (\car ->
                        let
                            positions =
                                car.laps
                                    |> List.map (.position >> Maybe.withDefault 0)
                                    |> List.take (List.length <| completedLapsAt raceClock car.laps)
                        in
                        history
                            { x = toFloat >> Scale.convert (xScale lapTotal)
                            , y = toFloat >> Scale.convert (yScale cars)
                            , svgPalette = Class.toStrokePalette car.class
                            , label = String.join " " [ car.carNumber, car.team ]
                            }
                            ( car, positions )
                    )
            )
        ]


history :
    { x : Int -> Float
    , y : Int -> Float
    , svgPalette : SvgPalette
    , label : String
    }
    -> ( Car, List Int )
    -> Svg msg
history { x, y, svgPalette, label } ( { carNumber, startPosition }, positions ) =
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
heading { x, y } children =
    g [ css [ fill (hsla 0 0 1 0.8) ] ] [ text_ [ InPx.x x, InPx.y y ] children ]


polyline_ : { svgPalette : SvgPalette } -> List ( Float, Float ) -> Svg msg
polyline_ options points_ =
    polyline [ css [ svgPalette options.svgPalette ], points points_ ] []


positionLabels : { label : Svg msg } -> List ( Float, Float ) -> List (Svg msg)
positionLabels { label } =
    List.map (\( x, y ) -> text_ [ InPx.x x, InPx.y y ] [ label ])
