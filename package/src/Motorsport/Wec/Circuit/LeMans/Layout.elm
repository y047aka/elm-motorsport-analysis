module Motorsport.Wec.Circuit.LeMans.Layout exposing (decoder, layout)

{-| The Circuit de la Sarthe as a map draws it: the lap, the pit lane beside
it, and where round the lap the lines it is timed at stand.

The lap itself arrives as the served geometry -- `static/geometry/le_mans.geojson`,
decoded and checked by [`Motorsport.Wec.Circuit.Geometry`](Motorsport-Wec-Circuit-Geometry).
What is written here is the season's distances and the drawing's lengths; the
record they are written into and the projection the degrees are drawn through
are [`Motorsport.Wec.Circuit.Layout`](Motorsport-Wec-Circuit-Layout), which every
circuit is drawn out of.

@docs decoder, layout

-}

import Json.Decode exposing (Decoder)
import Motorsport.Circuit.Shape as Shape exposing (Point, Shape)
import Motorsport.Sector as Sector exposing (Sector(..))
import Motorsport.Wec.Circuit.Geometry as Geometry exposing (Geometry)
import Motorsport.Wec.Circuit.Layout as Circuit exposing (Layout, MiniSectorLines(..), TimingLines)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (LeMans2025MiniSector(..))


{-| Reading the served geometry, checked against the 13,625.7 m Al Kamel's maps
give the centreline in every season from 2024.
-}
decoder : Decoder Geometry
decoder =
    Geometry.decoder { lapLength = 13625.7 }


{-| The circuit as a season's race was timed on it. A season after the last one
here is read as that one.
-}
layout : Int -> Geometry -> Layout
layout season geometry =
    let
        lap =
            shape geometry

        pit =
            pitLane geometry
    in
    { shape = lap
    , pitLane = pit
    , timingLines = timingLines season lap
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


{-| The "Approximate Distances" of Al Kamel's circuit map for each race, which
name six of the lines and not the rest. 2024's map gives Ford In apart from
Safety Car Line 1, and does not place the latter.
-}
timingLines : Int -> Shape -> TimingLines
timingLines season lap =
    if season <= 2024 then
        published
            { intermediate1 = 1899.09
            , intermediate2 = 7670.63
            , porscheIn = 11475.05
            , porscheOut = 12504.4
            , safetyCarLine1 = Nothing
            , fordOut = 13469.78
            }
            lap

    else if season == 2025 then
        published
            { intermediate1 = 1899.1
            , intermediate2 = 7670.63
            , porscheIn = 11475.05
            , porscheOut = 12504.4
            , safetyCarLine1 = Just 13251.0
            , fordOut = 13469.78
            }
            lap

    else
        published
            { intermediate1 = 1900.7
            , intermediate2 = 7672.13
            , porscheIn = 11475.77
            , porscheOut = 12507.09
            , safetyCarLine1 = Just 13246.35
            , fordOut = 13470.88
            }
            lap


published :
    { intermediate1 : Float
    , intermediate2 : Float
    , porscheIn : Float
    , porscheOut : Float
    , safetyCarLine1 : Maybe Float
    , fordOut : Float
    }
    -> Shape
    -> TimingLines
published lines lap =
    let
        finishLine =
            Shape.length lap
    in
    { sectors =
        Sector.initialize
            (\sector ->
                case sector of
                    S1 ->
                        lines.intermediate1

                    S2 ->
                        lines.intermediate2

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
                            Just lines.intermediate1

                        Z12 ->
                            Nothing

                        SCLC ->
                            Nothing

                        A7_1 ->
                            Nothing

                        IP2 ->
                            Just lines.intermediate2

                        A8_1 ->
                            Nothing

                        SCLB ->
                            Nothing

                        PORIN ->
                            Just lines.porscheIn

                        POROUT ->
                            Just lines.porscheOut

                        PITREF ->
                            Nothing

                        SCL1 ->
                            lines.safetyCarLine1

                        FORDOUT ->
                            Just lines.fordOut

                        FL ->
                            Just finishLine
                )
            )
    }
