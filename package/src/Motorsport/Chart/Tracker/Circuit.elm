module Motorsport.Chart.Tracker.Circuit exposing
    ( Circuit, fromLayout, view
    , Ground, ground
    )

{-| A circuit drawn to its own shape, flat: the lap, the pit lane beside it, the lines it is timed at, and the field placed round it.

@docs Circuit, fromLayout, view
@docs Ground, ground

-}

import Length exposing (Length)
import Motorsport.Chart.Tracker.Car as Car
import Motorsport.Chart.Tracker.Config as Config exposing (MiniSectorShares(..), TrackConfig)
import Motorsport.Chart.Tracker.Detail exposing (Detail(..), Labels(..))
import Motorsport.Chart.Tracker.LapScale as LapScale exposing (LapScale)
import Motorsport.Circuit.Direction exposing (Direction(..))
import Motorsport.Circuit.Pace as Pace
import Motorsport.Circuit.Relief as Relief exposing (Relief)
import Motorsport.Circuit.Shape as Shape exposing (Point, Shape)
import Motorsport.Race.Snapshot as Snapshot exposing (CarAt, Snapshot)
import Motorsport.Sector as Sector
import Motorsport.Wec.Circuit.Layout exposing (Layout, Lengths)
import Motorsport.Wec.Circuit.LeMans as LeMans
import Motorsport.Wec.Class as Class
import Quantity
import Svg exposing (Svg, g, line, polygon, polyline, svg, text, text_)
import Svg.Attributes exposing (class, dominantBaseline, fill, points, stroke, strokeLinejoin, textAnchor)
import Svg.Keyed as Keyed
import Svg.Lazy as Lazy
import TypedSvg.Attributes as Attributes exposing (strokeWidth, viewBox, x1, x2, y1, y2)
import TypedSvg.Types exposing (Transform(..), px)


{-| A circuit the app has a map of, ready to draw: hold on to it and hand it to [`view`](#view) each frame.
-}
type Circuit
    = Circuit Drawing


type alias Drawing =
    { direction : Direction
    , config : TrackConfig
    , shape : Shape
    , pitLane : List Point
    , relief : Maybe Relief
    , scale : LapScale
    , bounds : Bounds
    , lengths : { compact : Lengths, full : Lengths }
    }


type alias Bounds =
    { minX : Float
    , minY : Float
    , maxX : Float
    , maxY : Float
    }


{-| The track drawn to the circuit's own shape, with the cars placed by the lines it is timed at.
Between two lines a car runs at the pace the circuit's bends allow: see [`LapScale`](Motorsport-Chart-Tracker-LapScale).
The pit lane is drawn and no car is placed on it; the lap runs the direction its survey was chained in.

The lengths it is drawn at come with the circuit: see [`Lengths`](Motorsport-Wec-Circuit-Layout#Lengths).

-}
fromLayout : Layout -> { direction : Direction, config : TrackConfig } -> Circuit
fromLayout layout { direction, config } =
    Circuit
        { direction = direction
        , config = config
        , shape = layout.shape
        , pitLane = layout.pitLane
        , relief = layout.relief
        , scale = LapScale.lapScale (Pace.fromShape layout.relief layout.shape) layout.timingLines config
        , lengths = layout.lengths
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


{-| The circuit read on the ground it runs on, for a drawing of its own: the lines it is drawn from, in drawing metres, and every place along the lap -- a car, a sector boundary, a sector's name -- as its distance round the lap from the finish line, which `at` stands on the ground.

`relief` is how high the lines stand above their datum, for a circuit whose geometry carries heights: one per point of `lap` and of `pitLane`, and `at` a distance round the lap.

-}
type alias Ground =
    { lap : List Point
    , pitLane : List Point
    , at : Length -> Shape.Position
    , distanceOf : CarAt -> Length
    , boundaries : List Length
    , sectors : List { at : Length, label : String }
    , relief :
        Maybe
            { lap : List Length
            , pitLane : List Length
            , at : Length -> Length
            , lowest : Length
            }
    }


ground : Circuit -> Ground
ground (Circuit circuit) =
    { lap = List.map (\mark -> { x = mark.x, y = mark.y }) (Shape.marks circuit.shape)
    , pitLane = circuit.pitLane
    , at = \distance -> Shape.at (Length.inMeters distance) circuit.shape
    , distanceOf = LapScale.distanceOf circuit.scale
    , boundaries = List.map (LapScale.distanceAt circuit.scale) (Config.boundaries circuit.config)
    , sectors =
        circuit.config.sectors
            |> Sector.toList
            |> List.map
                (\( sector, { start, share } ) ->
                    { at = LapScale.distanceAt circuit.scale (start + share / 2)
                    , label = Sector.toString sector
                    }
                )
    , relief =
        Maybe.map
            (\relief ->
                { lap = List.map Length.meters (Relief.lap relief)
                , pitLane = List.map Length.meters (Relief.pitLane relief)
                , at = \distance -> Length.meters (Relief.at (Length.inMeters distance) relief)
                , lowest = Length.meters (Relief.lowest relief)
                }
            )
            circuit.relief
    }


{-| The circuit's lengths for one detail, in metres on the ground. The radii of `Labels` are read as distances from the line, outwards, and a negative one inwards.
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


{-| The circuit's lengths for the detail being drawn, in the shape the drawing
reads them. `Compact` carries no names, as the circuit said.
-}
circuitConstants : Detail -> Drawing -> CircuitConstants
circuitConstants detail circuit =
    let
        lengths =
            case detail of
                Compact ->
                    circuit.lengths.compact

                Full ->
                    circuit.lengths.full
    in
    { margin = lengths.margin
    , trackWidth = lengths.trackWidth
    , pitLaneWidth = lengths.pitLaneWidth
    , startFinishLineExtension = lengths.startFinishLineExtension
    , startFinishLineStrokeWidth = lengths.startFinishLineStrokeWidth
    , sectorBoundaryOffset = lengths.sectorBoundaryOffset
    , sectorBoundaryStrokeWidth = lengths.sectorBoundaryStrokeWidth
    , carSize = lengths.carSize
    , labels =
        case lengths.labels of
            Nothing ->
                NoLabels

            Just these ->
                Labels these
    }


{-| The circuit's own box, plus the margin the labels stand off in: the square
ring's viewBox would scale a tall circuit by its width alone, and such a
track would read much smaller than the card it is drawn in.

The svg keeps this box's proportions, and which axis binds is the box's doing and
not the drawing's. The visual tests give the column a 286x525 row, 0.545
wide-to-tall, and a box is fitted by height only below that: Le Mans's 4112 by
6787 is 0.61 and comes out 286 wide and 472 tall, COTA's 2245 by 1463 is 1.53 and
comes out 286 wide and 186. Both are fitted by width, and the band left under a
wide circuit is that circuit's shape rather than a length to tune.

-}
view : Detail -> Circuit -> Snapshot -> Svg msg
view detail (Circuit circuit) standings =
    let
        { margin } =
            circuitConstants detail circuit

        { minX, minY, maxX, maxY } =
            circuit.bounds
    in
    svg
        [ viewBox (minX - margin) (minY - margin) (maxX - minX + 2 * margin) (maxY - minY + 2 * margin)
        , class "h-full w-full"
        ]
        [ Lazy.lazy2 circuitTrack detail circuit
        , renderCarsOnCircuit detail circuit standings
        ]


circuitTrack : Detail -> Drawing -> Svg msg
circuitTrack detail circuit =
    let
        c =
            circuitConstants detail circuit

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
                { at = Quantity.zero
                , halfLength = c.startFinishLineExtension
                , color = "#fff"
                , width = c.startFinishLineStrokeWidth
                }

        boundaries =
            Config.boundaries circuit.config
                |> List.map
                    (\progress ->
                        across circuit
                            { at = LapScale.distanceAt circuit.scale progress
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


across : Drawing -> { at : Length, halfLength : Float, color : String, width : Float } -> Svg msg
across circuit { at, halfLength, color, width } =
    let
        position =
            Shape.at (Length.inMeters at) circuit.shape

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


circuitLabels : Labels -> Drawing -> List (Svg msg)
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
                                    { at = LapScale.distanceAt circuit.scale (start + share / 2)
                                    , offset = sectorRadius
                                    , fontSize = sectorFontSize
                                    , color = "oklch(1 0 0 / 0.5)"
                                    , label = Sector.toString sector
                                    }
                            )

                miniSectorLabels =
                    case circuit.config.miniSectors of
                        NoMiniSectors ->
                            []

                        MiniSectorShares shares ->
                            shares
                                |> LeMans.toList
                                |> List.filter (\( _, { share } ) -> share > 0)
                                |> List.map
                                    (\( mini, { start, share } ) ->
                                        labelOnCircuit circuit
                                            { at = LapScale.distanceAt circuit.scale (start + share)
                                            , offset = miniSectorRadius
                                            , fontSize = miniSectorFontSize
                                            , color = "oklch(0.5 0 0)"
                                            , label = LeMans.toString mini
                                            }
                                    )
            in
            sectorLabels ++ miniSectorLabels


labelOnCircuit :
    Drawing
    ->
        { at : Length
        , offset : Float
        , fontSize : Float
        , color : String
        , label : String
        }
    -> Svg msg
labelOnCircuit circuit { at, offset, fontSize, color, label } =
    let
        position =
            Shape.at (Length.inMeters at) circuit.shape

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


renderCarsOnCircuit : Detail -> Drawing -> Snapshot -> Svg msg
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


renderCarOnCircuit : Detail -> Drawing -> CarAt -> Svg msg
renderCarOnCircuit detail circuit car =
    let
        c =
            circuitConstants detail circuit

        position =
            Shape.at (Length.inMeters (LapScale.distanceOf circuit.scale car)) circuit.shape

        marker =
            g [ Attributes.transform [ Translate position.x position.y ] ]
                [ Lazy.lazy3 Car.marker c.carSize car.standing.positionInClass (Class.toColor car.metadata.class) ]
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
                , Car.label carFontSize
                    car.standing.positionInClass
                    { x = position.x + out.x * carRadius, y = position.y + out.y * carRadius }
                    { carNumber = car.metadata.carNumber }
                ]
