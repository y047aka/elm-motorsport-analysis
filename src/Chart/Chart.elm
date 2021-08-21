module Chart.Chart exposing (view)

import Axis exposing (tickCount, tickSizeInner, tickSizeOuter)
import Css exposing (block, display)
import Css.Extra exposing (strokeWidth, svgPalette)
import Css.Global exposing (descendants, each)
import Css.Palette.Svg exposing (..)
import Data.Car exposing (Car)
import Data.Class exposing (Class(..))
import Html.Styled exposing (Html)
import Scale exposing (ContinuousScale)
import Svg.Styled as Svg exposing (Svg, fromUnstyled, g, polyline, svg, text, text_)
import Svg.Styled.Attributes exposing (css)
import TypedSvg.Styled.Attributes exposing (points, transform, viewBox)
import TypedSvg.Styled.Attributes.InPx as InPx exposing (height, width)
import TypedSvg.Types exposing (Paint(..), Transform(..))


type alias OrdersByLap =
    List { lapNumber : Int, order : List Int }


w : Float
w =
    1600


h : Float
h =
    w * (9 / 16)


padding : { top : Float, left : Float, bottom : Float, right : Float }
padding =
    { top = 25 + 30, left = 20 + 190, bottom = 25 + 30, right = 20 }


xScale : OrdersByLap -> ContinuousScale Float
xScale ordersByLap =
    Scale.linear ( padding.left, w - padding.right ) ( 0, toFloat (List.length ordersByLap) )


yScale : List Car -> ContinuousScale Float
yScale cars =
    Scale.linear ( padding.top, h - padding.bottom ) ( 0, toFloat (List.length cars - 1) )


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
        [ g [ transform [ Translate 0 (padding.top - 20) ] ] [ axis Axis.top ]
        , g [ transform [ Translate 0 (h - padding.bottom + 20) ] ] [ axis Axis.bottom ]
        ]


view : { a | cars : List Car, ordersByLap : OrdersByLap } -> Html msg
view { cars, ordersByLap } =
    svg
        [ width w
        , height h
        , viewBox 0 0 w h
        , css [ display block ]
        ]
        [ xAxis ordersByLap
        , g []
            (cars
                |> List.sortBy .startPosition
                |> List.map
                    (\car ->
                        history
                            { x = toFloat >> Scale.convert (xScale ordersByLap)
                            , y = toFloat >> Scale.convert (yScale cars)
                            , svgPalette = svgPalette_ car.class
                            , label = String.join " " [ String.fromInt car.carNumber, car.team ]
                            }
                            car
                    )
            )
        ]


history :
    { x : Int -> Float
    , y : Int -> Float
    , svgPalette : SvgPalette
    , label : String
    }
    -> Car
    -> Svg msg
history { x, y, svgPalette, label } { carNumber, startPosition, positions } =
    history_
        { heading =
            heading
                { x = x <| -20
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
                |> positionLabels { label = text (String.fromInt carNumber) }
        }


history_ : { heading : Svg msg, positionLabels : List (Svg msg), polyline : Svg msg } -> Svg msg
history_ options =
    g []
        [ options.heading
        , options.polyline
        , g [] options.positionLabels
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


svgPalette_ : Class -> SvgPalette
svgPalette_ class =
    case class of
        LMH ->
            strokeLMP1

        LMP1 ->
            strokeLMP1

        LMP2 ->
            strokeLMP2

        LMGTE_Pro ->
            strokeGTEPro

        LMGTE_Am ->
            strokeGTEAm
