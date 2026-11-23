module Motorsport.Wec.Circuit.LeMans.Layout exposing (CircuitMap, mapDecoder, decoder, layout)

{-| The Circuit de la Sarthe as a map draws it: the lap, the pit lane beside
it, and where round the lap the lines it is timed at stand.

The lap itself arrives as the served geometry -- `static/geometry/le_mans.geojson`,
decoded and checked by [`Motorsport.Wec.Circuit.Geometry`](Motorsport-Wec-Circuit-Geometry).
Where its lines stand is the circuit map's, handed in as a [`CircuitMap`](#CircuitMap), and what is written here is the drawing's lengths.
The record they are written into and the projection the degrees are drawn through are [`Motorsport.Wec.Circuit.Layout`](Motorsport-Wec-Circuit-Layout), which every circuit is drawn out of.

@docs CircuitMap, mapDecoder, decoder, layout

-}

import Json.Decode as Decode exposing (Decoder)
import Motorsport.Circuit.Shape as Shape exposing (Point, Shape)
import Motorsport.Sector as Sector exposing (Sector(..))
import Motorsport.Wec.Circuit.Geometry as Geometry exposing (Geometry)
import Motorsport.Wec.Circuit.Layout as Circuit exposing (Layout, MiniSectorLines(..), TimingLines)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector(..))
import Motorsport.Wec.Circuit.Map as Map


{-| The figures of the circuit map the drawing is placed by, as its record at `static/circuit-maps/le_mans.json` gives them.

Every season is drawn on the record's map, the latest.

-}
type alias CircuitMap =
    { centreline : Float
    , intermediate1 : Float
    , intermediate2 : Float
    , porscheIn : Float
    , porscheOut : Float
    , fordIn : Float
    , fordOut : Float
    }


{-| Reading a map record, which has to give every figure in [`CircuitMap`](#CircuitMap), in the order a car reaches them.
-}
mapDecoder : Decoder CircuitMap
mapDecoder =
    Decode.map7 CircuitMap
        Map.centreline
        (Map.line "intermediate1")
        (Map.line "intermediate2")
        (Map.line "porscheIn")
        (Map.line "porscheOut")
        (Map.line "fordIn")
        (Map.line "fordOut")
        |> Decode.andThen (\map -> Map.inOrder map.centreline [ map.intermediate1, map.intermediate2, map.porscheIn, map.porscheOut, map.fordIn, map.fordOut ] map)


{-| Reading the served geometry, checked against the centreline the map gives.
-}
decoder : CircuitMap -> Decoder Geometry
decoder map =
    Geometry.decoder { lapLength = map.centreline }


{-| The circuit as the map places its lines.
-}
layout : CircuitMap -> Geometry -> Layout
layout map geometry =
    let
        lap =
            shape geometry
    in
    { shape = lap
    , pitLane = pitLane geometry
    , relief = Circuit.reliefOf geometry.centreline geometry.heights
    , timingLines = timingLines map lap
    , lengths = lengths
    }


{-| The lengths the tracker's drawing was measured against, in metres on the
ground: the car the field is drawn with, the ribbon, the margin and the names.
Every other circuit's set is read against this one.

`Compact` draws no names, so it carries none.

-}
lengths : { compact : Circuit.Lengths, full : Circuit.Lengths }
lengths =
    { compact =
        { margin = 150
        , trackWidth = 22
        , pitLaneWidth = 14
        , startFinishLineExtension = 130
        , startFinishLineStrokeWidth = 32
        , sectorBoundaryOffset = 105
        , sectorBoundaryStrokeWidth = 42
        , carSize = 105
        , labels = Nothing
        }
    , full =
        { margin = 700
        , trackWidth = 16
        , pitLaneWidth = 10
        , startFinishLineExtension = 160
        , startFinishLineStrokeWidth = 22
        , sectorBoundaryOffset = 108
        , sectorBoundaryStrokeWidth = 32
        , carSize = 97
        , labels =
            Just
                { sectorRadius = 380
                , sectorFontSize = 170
                , miniSectorRadius = -170
                , miniSectorFontSize = 120
                , carRadius = 190
                , carFontSize = 140
                }
        }
    }


shape : Geometry -> Shape
shape geometry =
    Circuit.shapeOf geometry.frame geometry.centreline


pitLane : Geometry -> List Point
pitLane geometry =
    Circuit.pitLaneOf geometry.frame geometry.pitLane


{-| The map names six of the feed's fifteen lines, and places the rest nowhere.
-}
timingLines : CircuitMap -> Shape -> TimingLines
timingLines map lap =
    let
        finishLine =
            Shape.length lap
    in
    { sectors =
        Sector.initialize
            (\sector ->
                case sector of
                    S1 ->
                        map.intermediate1

                    S2 ->
                        map.intermediate2

                    S3 ->
                        finishLine
            )
    , miniSectors =
        LeMansMiniSectors
            (LeMans.initialize
                (\mini ->
                    case mini of
                        SCL2 ->
                            Nothing

                        Z4 ->
                            Nothing

                        IP1 ->
                            Just map.intermediate1

                        Z12 ->
                            Nothing

                        SCLC ->
                            Nothing

                        A7_1 ->
                            Nothing

                        IP2 ->
                            Just map.intermediate2

                        A8_1 ->
                            Nothing

                        SCLB ->
                            Nothing

                        PORIN ->
                            Just map.porscheIn

                        POROUT ->
                            Just map.porscheOut

                        PITREF ->
                            Nothing

                        -- The map's timing loops name one line "SAFETY CAR LINE 1 / FORD IN".
                        SCL1 ->
                            Just map.fordIn

                        FORDOUT ->
                            Just map.fordOut

                        FL ->
                            Just finishLine
                )
            )
    }
