module Motorsport.Chart.Tracker exposing (view)

import Css exposing (center, displayFlex, justifyContent, position, px, sticky, top)
import Html.Styled exposing (Html, div, h2, text)
import Html.Styled.Attributes exposing (css)
import Motorsport.Class as Class exposing (Class)
import Motorsport.RaceControl as RaceControl
import Motorsport.RaceControl.ViewModel as ViewModel exposing (ViewModelItem)
import Svg.Styled as Svg
import Svg.Styled.Attributes as SvgAttrs


view : RaceControl.Model -> Html msg
view raceControl =
    let
        radius =
            450

        centerX =
            600

        centerY =
            600
    in
    div [ css [ displayFlex, justifyContent center ] ]
        [ div [ css [ position sticky, top (px 64) ] ]
            [ h2 [] [ text "Track Position Tracker" ]
            , div []
                [ Svg.svg
                    [ SvgAttrs.width "1200"
                    , SvgAttrs.height "1200"
                    , SvgAttrs.viewBox "0 0 1200 1200"
                    ]
                    [ trackCircle centerX centerY radius
                    , startFinishLine centerX centerY radius
                    , renderCars centerX centerY radius raceControl
                    ]
                ]
            ]
        ]


trackCircle : Int -> Int -> Int -> Svg.Svg msg
trackCircle centerX centerY radius =
    Svg.circle
        [ SvgAttrs.cx (String.fromInt centerX)
        , SvgAttrs.cy (String.fromInt centerY)
        , SvgAttrs.r (String.fromInt radius)
        , SvgAttrs.fill "none"
        , SvgAttrs.stroke "#333"
        , SvgAttrs.strokeWidth "4"
        ]
        []


startFinishLine : Int -> Int -> Int -> Svg.Svg msg
startFinishLine centerX centerY radius =
    Svg.line
        [ SvgAttrs.x1 (String.fromInt centerX)
        , SvgAttrs.y1 (String.fromInt (centerY - radius - 15))
        , SvgAttrs.x2 (String.fromInt centerX)
        , SvgAttrs.y2 (String.fromInt (centerY - radius + 15))
        , SvgAttrs.stroke "#fff"
        , SvgAttrs.strokeWidth "4"
        ]
        []


renderCars : Int -> Int -> Int -> RaceControl.Model -> Svg.Svg msg
renderCars centerX centerY radius raceControl =
    Svg.g []
        (ViewModel.init raceControl
            |> List.map (renderCar centerX centerY radius)
            |> List.reverse
        )


renderCar : Int -> Int -> Int -> ViewModelItem -> Svg.Svg msg
renderCar centerX centerY radius car =
    let
        cx =
            toFloat centerX

        cy =
            toFloat centerY

        r =
            toFloat radius

        -- Calculate sector-based progress
        progress =
            case car.currentLap of
                Nothing ->
                    0

                Just currentLap ->
                    -- Calculate progress based on which sector the car is in and sector times
                    let
                        sector1Weight =
                            0.33

                        -- Each sector represents about 1/3 of the lap
                        sector2Weight =
                            0.33

                        sector3Weight =
                            0.34

                        -- Small adjustment to ensure total = 1.0
                        -- Calculate progress based on sector data
                        sectorProgress =
                            case ( car.timing.sector_1, car.timing.sector_2, car.timing.sector_3 ) of
                                -- In sector 1
                                ( Just s1, Nothing, Nothing ) ->
                                    (s1.progress / 100) * sector1Weight

                                -- In sector 2
                                ( Just _, Just s2, Nothing ) ->
                                    sector1Weight + (s2.progress / 100) * sector2Weight

                                -- In sector 3
                                ( Just _, Just _, Just s3 ) ->
                                    sector1Weight + sector2Weight + (s3.progress / 100) * sector3Weight

                                -- Fallback to the original calculation if sector data is incomplete
                                _ ->
                                    min 1.0 (toFloat car.timing.time / toFloat currentLap.time)
                    in
                    sectorProgress

        -- Convert progress to angle (0 at 12 o'clock position, clockwise)
        angle =
            2 * pi * progress - (pi / 2)

        -- Calculate coordinates on the circle
        x =
            cx + r * cos angle

        y =
            cy + r * sin angle

        -- Get color based on car class
        carColor =
            Class.toHexColor 2025 car.metaData.class |> .value
    in
    Svg.g []
        [ Svg.circle
            [ SvgAttrs.cx (String.fromFloat x)
            , SvgAttrs.cy (String.fromFloat y)
            , SvgAttrs.r "15"
            , SvgAttrs.fill carColor
            ]
            []
        , Svg.text_
            [ SvgAttrs.x (String.fromFloat x)
            , SvgAttrs.y (String.fromFloat y)
            , SvgAttrs.fontSize "15"
            , SvgAttrs.textAnchor "middle"
            , SvgAttrs.dominantBaseline "central"
            , SvgAttrs.fill "#fff"
            ]
            [ Svg.text car.metaData.carNumber ]
        ]
