module Motorsport.Chart.Tracker exposing (Detail(..), Track, fromConfig, view)

{-| The field drawn going round the circuit.

@docs Detail, Track, fromConfig, view

-}

import Motorsport.Chart.Tracker.Config as Config exposing (TrackConfig)
import Motorsport.Circuit.Direction exposing (Direction(..))
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Sector as Sector
import Motorsport.Wec.Circuit.LeMans as LeMans
import Motorsport.Wec.Class as Class
import Scale exposing (ContinuousScale)
import Svg exposing (Svg, circle, g, line, svg, text, text_)
import Svg.Attributes exposing (class, dominantBaseline, fill, stroke, style, textAnchor)
import Svg.Keyed as Keyed
import Svg.Lazy as Lazy
import TypedSvg.Attributes as Attributes exposing (fontSize, strokeWidth, viewBox, x1, x2, y1, y2)
import TypedSvg.Types exposing (Transform(..), px)


{-| How much of the chart is drawn. The chart is scaled to whatever box it is
given, so every length below is divided by that box: at `Compact`'s size the
labels would stand a few pixels tall, so it carries none, and spends the room
they would need on the circle instead.
-}
type Detail
    = Compact
    | Full


type alias Constants =
    { viewBox : { w : Float, h : Float }
    , track :
        { cx : Float
        , cy : Float
        , r : Float
        , trackWidth : Float
        , startFinishLineExtension : Float
        , startFinishLineStrokeWidth : Float
        , sectorBoundaryOffset : Float
        , sectorBoundaryStrokeWidth : Float
        }
    , car : { size : Float }
    , labels : Labels
    }


type Labels
    = NoLabels
    | Labels
        { sectorRadius : Float
        , sectorFontSize : Float
        , miniSectorRadius : Float
        , miniSectorFontSize : Float
        , carRadius : Float
        , carFontSize : Float
        }


constants : Detail -> Constants
constants detail =
    case detail of
        Compact ->
            let
                -- No wider than the field drawn on the circle.
                size =
                    540
            in
            { viewBox = { w = size, h = size }
            , track =
                { cx = size / 2
                , cy = size / 2
                , r = 250
                , trackWidth = 2
                , startFinishLineExtension = 12
                , startFinishLineStrokeWidth = 3
                , sectorBoundaryOffset = 10
                , sectorBoundaryStrokeWidth = 4
                }
            , car = { size = 10 }
            , labels = NoLabels
            }

        Full ->
            let
                -- Wide enough for the sector labels outside the circle, and
                -- the font they are drawn in.
                size =
                    630
            in
            { viewBox = { w = size, h = size }
            , track =
                { cx = size / 2
                , cy = size / 2
                , r = 250
                , trackWidth = 1.5
                , startFinishLineExtension = 15
                , startFinishLineStrokeWidth = 2
                , sectorBoundaryOffset = 10
                , sectorBoundaryStrokeWidth = 3
                }
            , car = { size = 9 }
            , labels =
                Labels
                    { sectorRadius = 300
                    , sectorFontSize = 16
                    , miniSectorRadius = 230
                    , miniSectorFontSize = 12
                    , carRadius = 270
                    , carFontSize = 13
                    }
            }


{-| Scale function converting a track progress value (0-1) into an angle (radians).
Depending on rotation direction, maps to 0-2π clockwise or counter-clockwise from the 12 o'clock position.
-}
progressToAngleScale : Direction -> ContinuousScale Float
progressToAngleScale direction =
    let
        quarterTurn =
            pi / 2
    in
    case direction of
        Clockwise ->
            -- Map to 0-2π clockwise from the 12 o'clock position
            Scale.linear ( -quarterTurn, -quarterTurn + 2 * pi ) ( 0, 1 )

        CounterClockwise ->
            -- Map to 0-2π counter-clockwise from the 12 o'clock position
            Scale.linear ( -quarterTurn, -quarterTurn - 2 * pi ) ( 0, 1 )


{-| The circuit, drawn to the proportions the race ended up with. See
[`fromConfig`](#fromConfig).
-}
type Track
    = Track
        { direction : Direction
        , config : TrackConfig
        }


{-| The track as the summary describes it. Hold on to the result and hand it to
[`view`](#view) each frame.
-}
fromConfig : { direction : Direction, config : TrackConfig } -> Track
fromConfig =
    Track


view : Detail -> Track -> Snapshot -> Svg msg
view detail (Track { direction, config }) standings =
    viewWithConfig detail direction config standings


viewWithConfig : Detail -> Direction -> TrackConfig -> Snapshot -> Svg msg
viewWithConfig detail direction config standings =
    let
        { w, h } =
            (constants detail).viewBox
    in
    svg
        [ viewBox 0 0 w h
        , class "max-w-full max-h-full"
        ]
        [ Lazy.lazy3 track detail direction config
        , renderCars detail direction config standings
        ]


track : Detail -> Direction -> TrackConfig -> Svg msg
track detail direction config =
    let
        c =
            constants detail

        { cx, cy, r, trackWidth } =
            c.track

        trackCircle color width =
            circle
                [ Attributes.cx (px cx)
                , Attributes.cy (px cy)
                , Attributes.r (px r)
                , fill "none"
                , stroke color
                , strokeWidth (px width)
                ]
                []

        outerTrackCircle =
            trackCircle "oklch(1 0 0 / 0.2)" trackWidth

        startFinishLine =
            line
                [ x1 (px cx)
                , y1 (px (cy - r - c.track.startFinishLineExtension))
                , x2 (px cx)
                , y2 (px (cy - r + c.track.startFinishLineExtension))
                , stroke "#fff"
                , strokeWidth (px c.track.startFinishLineStrokeWidth)
                ]
                []

        makeBoundary angle =
            line
                [ x1 (px (cx + (r - c.track.sectorBoundaryOffset) * cos angle))
                , y1 (px (cy + (r - c.track.sectorBoundaryOffset) * sin angle))
                , x2 (px (cx + (r + c.track.sectorBoundaryOffset) * cos angle))
                , y2 (px (cy + (r + c.track.sectorBoundaryOffset) * sin angle))
                , stroke "oklch(0.23 0 0)"
                , strokeWidth (px c.track.sectorBoundaryStrokeWidth)
                ]
                []

        boundaries =
            Config.calcSectorBoundaries config
                |> List.map (Scale.convert (progressToAngleScale direction))
                |> List.map (\angle -> makeBoundary angle)

        sectorLabels =
            renderSectorLabels detail direction config

        miniSectorLabels =
            renderMiniSectorLabels detail direction config
    in
    g [] (outerTrackCircle :: boundaries ++ startFinishLine :: sectorLabels ++ miniSectorLabels)


renderSectorLabels : Detail -> Direction -> TrackConfig -> List (Svg msg)
renderSectorLabels detail direction config =
    case (constants detail).labels of
        NoLabels ->
            []

        Labels { sectorRadius, sectorFontSize } ->
            config.sectors
                |> Sector.toList
                |> List.map
                    (\( sector, { start, share } ) ->
                        makeLabel detail
                            direction
                            { progress = start + (share / 2)
                            , radius = sectorRadius
                            , fontSize = sectorFontSize
                            , color = "oklch(1 0 0 / 0.5)"
                            , label = Sector.toString sector
                            }
                    )


renderMiniSectorLabels : Detail -> Direction -> TrackConfig -> List (Svg msg)
renderMiniSectorLabels detail direction config =
    case ( (constants detail).labels, config.miniSectors ) of
        ( NoLabels, _ ) ->
            []

        ( _, Config.NoMiniSectors ) ->
            []

        ( Labels { miniSectorRadius, miniSectorFontSize }, Config.MiniSectorShares shares ) ->
            shares
                |> LeMans.toList
                |> List.map
                    (\( mini, { start, share } ) ->
                        makeLabel detail
                            direction
                            -- At the end of the mini-sector, not the middle of
                            -- it as a sector's label is: fifteen of them round
                            -- one circle leaves no room to centre them in.
                            { progress = start + share
                            , radius = miniSectorRadius
                            , fontSize = miniSectorFontSize
                            , color = "oklch(0.5 0 0)"
                            , label = LeMans.toString mini
                            }
                    )


makeLabel :
    Detail
    -> Direction
    ->
        { progress : Float
        , radius : Float
        , fontSize : Float
        , color : String
        , label : String
        }
    -> Svg msg
makeLabel detail direction { progress, radius, fontSize, color, label } =
    let
        { cx, cy } =
            (constants detail).track

        angle =
            Scale.convert (progressToAngleScale direction) progress

        labelX =
            cx + radius * cos angle

        labelY =
            cy + radius * sin angle
    in
    text_
        [ Attributes.x (px labelX)
        , Attributes.y (px labelY)
        , Attributes.fontSize (px fontSize)
        , textAnchor "middle"
        , dominantBaseline "central"
        , fill color
        ]
        [ text label ]


renderCars : Detail -> Direction -> TrackConfig -> Snapshot -> Svg msg
renderCars detail direction config standings =
    Keyed.node "g"
        []
        (Snapshot.toList standings
            |> List.reverse
            |> List.map
                (\car ->
                    ( car.metadata.carNumber
                    , Lazy.lazy4 renderCarOnTrack detail direction config car
                    )
                )
        )


renderCarOnTrack : Detail -> Direction -> TrackConfig -> CarAt -> Svg msg
renderCarOnTrack detail direction config car =
    let
        coords =
            coordinatesOnTrack detail direction config car
    in
    renderCar detail car coords


coordinatesOnTrack : Detail -> Direction -> TrackConfig -> CarAt -> { angle : Float, x : Float, y : Float }
coordinatesOnTrack detail direction config car =
    let
        { cx, cy, r } =
            (constants detail).track

        progress =
            Config.computeProgress config car

        angle =
            Scale.convert (progressToAngleScale direction) progress
    in
    { angle = angle
    , x = cx + r * cos angle
    , y = cy + r * sin angle
    }


renderCar : Detail -> CarAt -> { angle : Float, x : Float, y : Float } -> Svg msg
renderCar detail car { angle, x, y } =
    let
        c =
            constants detail

        { cx, cy } =
            c.track

        marker =
            g [ Attributes.transform [ Translate x y ] ]
                [ Lazy.lazy3 carMarker c.car.size car.standing.positionInClass (Class.toColor car.metadata.class) ]
    in
    case c.labels of
        NoLabels ->
            marker

        Labels { carRadius, carFontSize } ->
            g []
                [ marker
                , carLabel carFontSize
                    car.standing.positionInClass
                    { x = cx + carRadius * cos angle, y = cy + carRadius * sin angle }
                    { carNumber = car.metadata.carNumber }
                ]


carMarker : Float -> Int -> String -> Svg msg
carMarker size positionInClass classColorValue =
    let
        scaleFactor =
            max 0.4 (1 - (toFloat positionInClass * 0.1))

        carSize =
            size * scaleFactor

        saturation =
            if positionInClass <= 3 then
                "100%"

            else
                "50%"
    in
    circle
        [ Attributes.cx (px 0)
        , Attributes.cy (px 0)
        , Attributes.r (px carSize)
        , fill classColorValue
        , style ("filter: saturate(" ++ saturation ++ ");")
        ]
        []


carLabel : Float -> Int -> { x : Float, y : Float } -> { carNumber : String } -> Svg msg
carLabel labelFontSize positionInClass { x, y } { carNumber } =
    let
        scaleFactor =
            max 0.75 (1 - (toFloat positionInClass * 0.02))
    in
    text_
        [ Attributes.x (px x)
        , Attributes.y (px y)
        , fontSize (px (labelFontSize * scaleFactor))
        , textAnchor "middle"
        , dominantBaseline "central"
        , fill "oklch(1 0 0 / 0.7)"
        ]
        [ text carNumber ]
