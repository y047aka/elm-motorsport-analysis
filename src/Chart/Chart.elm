module Chart.Chart exposing (lapChart)

import Axis exposing (tickCount, tickSizeInner, tickSizeOuter)
import Css exposing (block, display)
import Css.Extra exposing (strokeWidth, svgPalette)
import Css.Global exposing (descendants, each)
import Css.Palette.Svg exposing (..)
import Data.Car exposing (Car)
import Data.Class exposing (Class(..))
import Html.Styled exposing (text)
import Scale exposing (ContinuousScale)
import Svg.Styled as Svg exposing (Svg, fromUnstyled, g, svg)
import Svg.Styled.Attributes as Svg
import TypedSvg.Styled.Attributes exposing (points, transform, viewBox)
import TypedSvg.Styled.Attributes.InPx exposing (height, width, x, y)
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
        [ Svg.css
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


lapChart : { a | cars : List Car, ordersByLap : OrdersByLap } -> Svg msg
lapChart { cars, ordersByLap } =
    svg
        [ width w
        , height h
        , viewBox 0 0 w h
        , Svg.css [ display block ]
        ]
        [ xAxis ordersByLap
        , g []
            (cars
                |> List.sortBy .startPosition
                |> List.map
                    (historyFor
                        { x = toFloat >> Scale.convert (xScale ordersByLap)
                        , y = toFloat >> Scale.convert (yScale cars)
                        }
                    )
            )
        ]


historyFor : { x : Int -> Float, y : Int -> Float } -> Car -> Svg msg
historyFor options car =
    g []
        [ heading
            { x = options.x
            , y = options.y
            , label = String.join " " [ String.fromInt car.carNumber, car.team ]
            }
            car.startPosition

        -- , positionsGroup
        --     { x = options.x
        --     , y = options.y
        --     , label = String.fromInt car.carNumber
        --     }
        --     car
        , polyline
            { x = options.x
            , y = options.y
            , svgPalette = svgPalette_ car.class
            }
            car
        ]


heading : { x : Int -> Float, y : Int -> Float, label : String } -> Int -> Svg msg
heading options startPosition =
    g []
        [ Svg.text_
            [ x <| options.x -20
            , y <| (options.y >> (+) 5) startPosition
            ]
            [ text options.label ]
        ]


polyline : { x : Int -> Float, y : Int -> Float, svgPalette : SvgPalette } -> Car -> Svg msg
polyline options { startPosition, positions } =
    Svg.polyline
        [ Svg.css [ svgPalette options.svgPalette ]
        , points <|
            List.indexedMap
                (\index position -> ( options.x index, options.y position ))
                (startPosition :: positions)
        ]
        []


svgPalette_ : Class -> SvgPalette
svgPalette_ class =
    case class of
        LMP1 ->
            strokeLMP1

        LMP2 ->
            strokeLMP2

        LMGTE_Pro ->
            strokeGTEPro

        LMGTE_Am ->
            strokeGTEAm


positionsGroup : { x : Int -> Float, y : Int -> Float, label : String } -> Car -> Svg msg
positionsGroup options { startPosition, positions } =
    g [] <|
        List.indexedMap
            (\index position ->
                Svg.text_
                    [ x (options.x index)
                    , y (options.y position)
                    ]
                    [ text options.label ]
            )
            (startPosition :: positions)
