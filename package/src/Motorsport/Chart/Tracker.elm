module Motorsport.Chart.Tracker exposing (Detail(..), Track, fromConfig, onCircuit, view)

{-| The field drawn going round the circuit.

@docs Detail, Track, fromConfig, onCircuit, view

-}

import Motorsport.Chart.Tracker.Config as Config exposing (LapScale, TrackConfig)
import Motorsport.Circuit.Direction exposing (Direction(..))
import Motorsport.Circuit.Shape as Shape exposing (Point, Shape)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Sector as Sector
import Motorsport.Wec.Circuit.LeMans as LeMans
import Motorsport.Wec.Circuit.LeMans.Layout exposing (Layout)
import Motorsport.Wec.Class as Class
import Scale exposing (ContinuousScale)
import Svg exposing (Svg, circle, g, line, polygon, polyline, svg, text, text_)
import Svg.Attributes exposing (class, dominantBaseline, fill, points, stroke, strokeLinejoin, style, textAnchor)
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


{-| A track progress (0-1) as an angle in radians, round from 12 o'clock in the
direction the circuit is driven.
-}
progressToAngleScale : Direction -> ContinuousScale Float
progressToAngleScale direction =
    let
        quarterTurn =
            pi / 2
    in
    case direction of
        Clockwise ->
            Scale.linear ( -quarterTurn, -quarterTurn + 2 * pi ) ( 0, 1 )

        CounterClockwise ->
            Scale.linear ( -quarterTurn, -quarterTurn - 2 * pi ) ( 0, 1 )


{-| The circuit, drawn as a circle to the proportions the race ended up with,
or to its own shape. See [`fromConfig`](#fromConfig) and
[`onCircuit`](#onCircuit).
-}
type Track
    = Ring
        { direction : Direction
        , config : TrackConfig
        }
    | OnCircuit Circuit


type alias Circuit =
    { direction : Direction
    , config : TrackConfig
    , shape : Shape
    , pitLane : List Point
    , scale : LapScale
    , bounds : Bounds
    }


type alias Bounds =
    { minX : Float
    , minY : Float
    , maxX : Float
    , maxY : Float
    }


{-| The track as the summary describes it. Hold on to the result and hand it to
[`view`](#view) each frame.
-}
fromConfig : { direction : Direction, config : TrackConfig } -> Track
fromConfig =
    Ring


{-| The track drawn to the circuit's own shape, with the cars placed by the
lines it is timed at. The pit lane is drawn and no car is placed on it.
-}
onCircuit : Layout -> { direction : Direction, config : TrackConfig } -> Track
onCircuit layout { direction, config } =
    OnCircuit
        { direction = direction
        , config = config
        , shape = layout.shape
        , pitLane = layout.pitLane
        , scale = Config.lapScale layout.timingLines config
        , bounds =
            boundsOf
                (List.map (\mark -> { x = mark.x, y = mark.y }) (Shape.marks layout.shape)
                    ++ layout.pitLane
                )
        }


boundsOf : List Point -> Bounds
boundsOf corners =
    case corners of
        [] ->
            { minX = 0, minY = 0, maxX = 0, maxY = 0 }

        first :: rest ->
            List.foldl
                (\p b ->
                    { minX = min b.minX p.x
                    , minY = min b.minY p.y
                    , maxX = max b.maxX p.x
                    , maxY = max b.maxY p.y
                    }
                )
                { minX = first.x, minY = first.y, maxX = first.x, maxY = first.y }
                rest


view : Detail -> Track -> Snapshot -> Svg msg
view detail shown standings =
    case shown of
        Ring { direction, config } ->
            viewWithConfig detail direction config standings

        OnCircuit circuit ->
            viewOnCircuit detail circuit standings


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



-- ON THE CIRCUIT'S SHAPE


{-| The ring's lengths again, in metres on the ground: each is the ring's own,
times the metres one unit of its drawing comes to when the circuit is drawn in
the same box. The radii of `Labels` are read as distances from the line,
outwards, and a negative one inwards.
-}
type alias CircuitConstants =
    { margin : Float
    , trackWidth : Float
    , pitLaneWidth : Float
    , startFinishLineExtension : Float
    , startFinishLineStrokeWidth : Float
    , sectorBoundaryOffset : Float
    , sectorBoundaryStrokeWidth : Float
    , carSize : Float
    , labels : Labels
    }


circuitConstants : Detail -> CircuitConstants
circuitConstants detail =
    case detail of
        Compact ->
            { margin = 150
            , trackWidth = 22
            , pitLaneWidth = 14
            , startFinishLineExtension = 130
            , startFinishLineStrokeWidth = 32
            , sectorBoundaryOffset = 105
            , sectorBoundaryStrokeWidth = 42
            , carSize = 105
            , labels = NoLabels
            }

        Full ->
            { margin = 700
            , trackWidth = 16
            , pitLaneWidth = 10
            , startFinishLineExtension = 160
            , startFinishLineStrokeWidth = 22
            , sectorBoundaryOffset = 108
            , sectorBoundaryStrokeWidth = 32
            , carSize = 97
            , labels =
                Labels
                    { sectorRadius = 380
                    , sectorFontSize = 170
                    , miniSectorRadius = -170
                    , miniSectorFontSize = 120
                    , carRadius = 190
                    , carFontSize = 140
                    }
            }


{-| Square, as the ring is, however long the circuit runs one way: the box it
is drawn in settles its height only through its width, so a drawing taller than
it is wide is scaled to the width and overflows it.
-}
viewOnCircuit : Detail -> Circuit -> Snapshot -> Svg msg
viewOnCircuit detail circuit standings =
    let
        { margin } =
            circuitConstants detail

        { minX, minY, maxX, maxY } =
            circuit.bounds

        side =
            max (maxX - minX) (maxY - minY) + 2 * margin
    in
    svg
        [ viewBox ((minX + maxX - side) / 2) ((minY + maxY - side) / 2) side side
        , class "max-w-full max-h-full"
        ]
        [ Lazy.lazy2 circuitTrack detail circuit
        , renderCarsOnCircuit detail circuit standings
        ]


circuitTrack : Detail -> Circuit -> Svg msg
circuitTrack detail circuit =
    let
        c =
            circuitConstants detail

        pitLane =
            polyline
                [ points (pointsAttribute circuit.pitLane)
                , fill "none"
                , stroke "oklch(1 0 0 / 0.1)"
                , strokeWidth (px c.pitLaneWidth)
                , strokeLinejoin "round"
                ]
                []

        lap =
            polygon
                [ points (pointsAttribute (List.map (\mark -> { x = mark.x, y = mark.y }) (Shape.marks circuit.shape)))
                , fill "none"
                , stroke "oklch(1 0 0 / 0.2)"
                , strokeWidth (px c.trackWidth)
                , strokeLinejoin "round"
                ]
                []

        startFinishLine =
            across circuit
                { metres = 0
                , halfLength = c.startFinishLineExtension
                , color = "#fff"
                , width = c.startFinishLineStrokeWidth
                }

        boundaries =
            Config.calcSectorBoundaries circuit.config
                |> List.map
                    (\progress ->
                        across circuit
                            { metres = Config.toMetres circuit.scale progress
                            , halfLength = c.sectorBoundaryOffset
                            , color = "oklch(0.23 0 0)"
                            , width = c.sectorBoundaryStrokeWidth
                            }
                    )
    in
    g [] (pitLane :: lap :: boundaries ++ startFinishLine :: circuitLabels c.labels circuit)


pointsAttribute : List Point -> String
pointsAttribute =
    List.map (\p -> String.fromFloat p.x ++ "," ++ String.fromFloat p.y)
        >> String.join " "


across : Circuit -> { metres : Float, halfLength : Float, color : String, width : Float } -> Svg msg
across circuit { metres, halfLength, color, width } =
    let
        position =
            Shape.at metres circuit.shape

        out =
            outward circuit.direction position.heading
    in
    line
        [ x1 (px (position.x - out.x * halfLength))
        , y1 (px (position.y - out.y * halfLength))
        , x2 (px (position.x + out.x * halfLength))
        , y2 (px (position.y + out.y * halfLength))
        , stroke color
        , strokeWidth (px width)
        ]
        []


{-| The side of the line away from the infield, one metre long. `y` runs down
the drawing, so a lap driven clockwise has its infield to the right of the way
it runs.
-}
outward : Direction -> Point -> Point
outward direction heading =
    case direction of
        Clockwise ->
            { x = heading.y, y = negate heading.x }

        CounterClockwise ->
            { x = negate heading.y, y = heading.x }


circuitLabels : Labels -> Circuit -> List (Svg msg)
circuitLabels labels circuit =
    case labels of
        NoLabels ->
            []

        Labels { sectorRadius, sectorFontSize, miniSectorRadius, miniSectorFontSize } ->
            let
                sectorLabels =
                    circuit.config.sectors
                        |> Sector.toList
                        |> List.map
                            (\( sector, { start, share } ) ->
                                labelOnCircuit circuit
                                    { metres = Config.toMetres circuit.scale (start + share / 2)
                                    , offset = sectorRadius
                                    , fontSize = sectorFontSize
                                    , color = "oklch(1 0 0 / 0.5)"
                                    , label = Sector.toString sector
                                    }
                            )

                miniSectorLabels =
                    case circuit.config.miniSectors of
                        Config.NoMiniSectors ->
                            []

                        Config.MiniSectorShares shares ->
                            shares
                                |> LeMans.toList
                                |> List.filter (\( _, { share } ) -> share > 0)
                                |> List.map
                                    (\( mini, { start, share } ) ->
                                        labelOnCircuit circuit
                                            { metres = Config.toMetres circuit.scale (start + share)
                                            , offset = miniSectorRadius
                                            , fontSize = miniSectorFontSize
                                            , color = "oklch(0.5 0 0)"
                                            , label = LeMans.toString mini
                                            }
                                    )
            in
            sectorLabels ++ miniSectorLabels


labelOnCircuit :
    Circuit
    ->
        { metres : Float
        , offset : Float
        , fontSize : Float
        , color : String
        , label : String
        }
    -> Svg msg
labelOnCircuit circuit { metres, offset, fontSize, color, label } =
    let
        position =
            Shape.at metres circuit.shape

        out =
            outward circuit.direction position.heading
    in
    text_
        [ Attributes.x (px (position.x + out.x * offset))
        , Attributes.y (px (position.y + out.y * offset))
        , Attributes.fontSize (px fontSize)
        , textAnchor
            (anchorAway
                (if offset < 0 then
                    negate out.x

                 else
                    out.x
                )
            )
        , dominantBaseline "central"
        , fill color
        ]
        [ text label ]


{-| A label set off to the side of the line reads away from it; one set off
above or below it is centred on it.
-}
anchorAway : Float -> String
anchorAway sideways =
    if sideways > 0.35 then
        "start"

    else if sideways < -0.35 then
        "end"

    else
        "middle"


renderCarsOnCircuit : Detail -> Circuit -> Snapshot -> Svg msg
renderCarsOnCircuit detail circuit standings =
    Keyed.node "g"
        []
        (Snapshot.toList standings
            |> List.reverse
            |> List.map
                (\car ->
                    ( car.metadata.carNumber
                    , Lazy.lazy3 renderCarOnCircuit detail circuit car
                    )
                )
        )


renderCarOnCircuit : Detail -> Circuit -> CarAt -> Svg msg
renderCarOnCircuit detail circuit car =
    let
        c =
            circuitConstants detail

        position =
            Shape.at (Config.toMetres circuit.scale (Config.computeProgress circuit.config car)) circuit.shape

        marker =
            g [ Attributes.transform [ Translate position.x position.y ] ]
                [ Lazy.lazy3 carMarker c.carSize car.standing.positionInClass (Class.toColor car.metadata.class) ]
    in
    case c.labels of
        NoLabels ->
            marker

        Labels { carRadius, carFontSize } ->
            let
                out =
                    outward circuit.direction position.heading
            in
            g []
                [ marker
                , carLabel carFontSize
                    car.standing.positionInClass
                    { x = position.x + out.x * carRadius, y = position.y + out.y * carRadius }
                    { carNumber = car.metadata.carNumber }
                ]
