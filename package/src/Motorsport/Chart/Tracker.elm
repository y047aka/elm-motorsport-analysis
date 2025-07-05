module Motorsport.Chart.Tracker exposing (view, viewWithMiniSectors)

import Css exposing (maxWidth, pct)
import Motorsport.Analysis exposing (Analysis)
import Motorsport.Chart.Tracker.Config as Config exposing (TrackConfig)
import Motorsport.Class as Class
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel as ViewModel exposing (ViewModelItem)
import Svg.Styled exposing (Svg, circle, g, line, svg, text, text_)
import Svg.Styled.Attributes exposing (css, dominantBaseline, fill, stroke, textAnchor)
import Svg.Styled.Keyed as Keyed
import Svg.Styled.Lazy as Lazy
import TypedSvg.Styled.Attributes as Attributes exposing (cx, cy, fontSize, height, r, strokeWidth, viewBox, width, x1, x2, y1, y2)
import TypedSvg.Types exposing (px)


view : Analysis -> RaceControl.Model -> Svg msg
view analysis raceControl =
    let
        config =
            Config.standard analysis
    in
    viewWithConfig config raceControl


viewWithMiniSectors : Analysis -> RaceControl.Model -> Svg msg
viewWithMiniSectors analysis raceControl =
    let
        config =
            Config.leMans24h analysis
    in
    viewWithConfig config raceControl


viewWithConfig : TrackConfig -> RaceControl.Model -> Svg msg
viewWithConfig config raceControl =
    svg
        [ width (px 1000)
        , height (px 1000)
        , viewBox 0 0 1000 1000
        , css [ maxWidth (pct 100) ]
        ]
        [ Lazy.lazy track config
        , renderCars config raceControl
        ]


track : TrackConfig -> Svg msg
track config =
    let
        { cx, cy, r } =
            config

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

        makeBoundary angle =
            line
                [ x1 (px (cx + (r - 10) * cos angle))
                , y1 (px (cy + (r - 10) * sin angle))
                , x2 (px (cx + (r + 10) * cos angle))
                , y2 (px (cy + (r + 10) * sin angle))
                , stroke "#aaa"
                , strokeWidth (px 3)
                ]
                []

        boundaries =
            Config.calcSectorBoundaries config.sectorConfig
                |> List.map (\angle -> makeBoundary angle)
    in
    g [] (trackCircle :: startFinishLine :: boundaries)


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
coordinatesOnTrack config car =
    let
        { cx, cy, r } =
            config

        progress =
            Config.calcSectorProgress config.sectorConfig car

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
