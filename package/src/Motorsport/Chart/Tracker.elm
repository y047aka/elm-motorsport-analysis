module Motorsport.Chart.Tracker exposing (view)

import Motorsport.Class as Class
import Motorsport.Lap exposing (Sector(..))
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel as ViewModel exposing (ViewModelItem)
import Svg.Styled exposing (Svg, circle, g, line, svg, text, text_)
import Svg.Styled.Attributes exposing (dominantBaseline, fill, stroke, textAnchor)
import Svg.Styled.Keyed as Keyed
import Svg.Styled.Lazy as Lazy
import TypedSvg.Styled.Attributes as Attributes exposing (cx, cy, fontSize, height, r, strokeWidth, viewBox, width, x1, x2, y1, y2)
import TypedSvg.Types exposing (px)


type alias TrackConfig =
    { cx : Float, cy : Float, r : Float }


view : RaceControl.Model -> Svg msg
view raceControl =
    let
        config =
            { cx = 600, cy = 600, r = 450 }
    in
    svg
        [ width (px 1200)
        , height (px 1200)
        , viewBox 0 0 1200 1200
        ]
        [ Lazy.lazy track config
        , renderCars config raceControl
        ]


track : TrackConfig -> Svg msg
track { cx, cy, r } =
    let
        trackCircle =
            circle
                [ Attributes.cx (px cx)
                , Attributes.cy (px cy)
                , Attributes.r (px r)
                , fill "none"
                , stroke "#333"
                , strokeWidth (px 4)
                ]
                []

        startFinishLine =
            line
                [ x1 (px cx)
                , y1 (px (cy - r - 15))
                , x2 (px cx)
                , y2 (px (cy - r + 15))
                , stroke "#fff"
                , strokeWidth (px 4)
                ]
                []
    in
    g [] [ trackCircle, startFinishLine ]


renderCars : TrackConfig -> RaceControl.Model -> Svg msg
renderCars config raceControl =
    Keyed.node "g"
        []
        (ViewModel.init raceControl
            |> List.reverse
            |> List.map (\car -> ( car.metaData.carNumber, Lazy.lazy2 renderCarOnTrack config car ))
        )


renderCarOnTrack : TrackConfig -> ViewModelItem -> Svg msg
renderCarOnTrack config car =
    coordinatesOnTrack config car
        |> renderCar car


coordinatesOnTrack : TrackConfig -> ViewModelItem -> { x : Float, y : Float }
coordinatesOnTrack { cx, cy, r } car =
    let
        progress =
            calcProgress car

        -- Convert progress to angle (0 at 12 o'clock position, clockwise)
        angle =
            2 * pi * progress - (pi / 2)
    in
    { x = cx + r * cos angle
    , y = cy + r * sin angle
    }


renderCar : ViewModelItem -> { x : Float, y : Float } -> Svg msg
renderCar car { x, y } =
    let
        carColor =
            Class.toHexColor 2025 car.metaData.class |> .value

        carCircle =
            circle
                [ Attributes.cx (px x)
                , Attributes.cy (px y)
                , Attributes.r (px 15)
                , fill carColor
                ]
                []

        carNumber =
            text_
                [ Attributes.x (px x)
                , Attributes.y (px y)
                , fontSize (px 15)
                , textAnchor "middle"
                , dominantBaseline "central"
                , fill "#fff"
                ]
                [ text car.metaData.carNumber ]
    in
    g [] [ carCircle, carNumber ]


calcProgress : ViewModelItem -> Float
calcProgress car =
    let
        ( sector1Weight, sector2Weight, sector3Weight ) =
            ( 0.33, 0.33, 0.34 )
    in
    case car.timing.sector of
        Just ( S1, progress ) ->
            (progress / 100) * sector1Weight

        Just ( S2, progress ) ->
            sector1Weight + (progress / 100) * sector2Weight

        Just ( S3, progress ) ->
            sector1Weight + sector2Weight + (progress / 100) * sector3Weight

        -- Fallback to the original calculation if sector data is incomplete
        Nothing ->
            case car.currentLap of
                Nothing ->
                    0

                Just currentLap ->
                    min 1.0 (toFloat car.timing.time / toFloat currentLap.time)
