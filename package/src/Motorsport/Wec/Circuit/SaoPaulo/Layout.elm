module Motorsport.Wec.Circuit.SaoPaulo.Layout exposing (decoder, layout)

{-| São Paulo's Autódromo José Carlos Pace as a map draws it: the lap, the pit
lane beside it, and where round the lap the lines it is timed at stand.

The lap itself arrives as the served geometry -- `static/geometry/sao_paulo.geojson`,
decoded and checked by [`Motorsport.Wec.Circuit.Geometry`](Motorsport-Wec-Circuit-Geometry)
-- and what is written here is what the file cannot know: the drawing's lengths
and the lines the round is timed at. The record and the projection the degrees
are drawn through are
[`Motorsport.Circuit.Layout`](Motorsport-Circuit-Layout), which every
circuit is drawn out of.

@docs decoder, layout

-}

import Json.Decode exposing (Decoder)
import Motorsport.Circuit.Layout as Circuit exposing (Layout, MiniSectorLines(..), TimingLines)
import Motorsport.Circuit.Shape as Shape exposing (Point, Shape)
import Motorsport.Sector as Sector exposing (Sector(..))
import Motorsport.Wec.Circuit.Geometry as Geometry exposing (Geometry)
import Motorsport.Wec.Circuit.Map exposing (Intermediates)


{-| Reading the served geometry against the centreline its map gives, which is what the survey was stretched to.
-}
decoder : Intermediates -> Decoder Geometry
decoder map =
    Geometry.decoder { lapLength = map.centreline }


{-| The circuit, on the lines its map puts round the lap -- see
[`timingLines`](#timingLines).

The lap runs the direction its survey was chained in -- the word arrives with
the geometry, as OpenStreetMap's own one-way tags say it.

-}
layout : Intermediates -> Geometry -> Layout
layout map geometry =
    let
        lap =
            shape geometry

        pit =
            pitLane geometry
    in
    { shape = lap
    , pitLane = pit
    , relief = Circuit.reliefOf geometry.centreline geometry.heights
    , timingLines = timingLines map lap
    , lengths = lengths
    }


{-| The lengths this drawing is measured at, in metres on the ground.

`Full` is measured so that its furniture comes to the same pixels as Le Mans's,
the way COTA's, Barcelona's, Monza's and Spa's are. The tracker draws every
circuit in one portrait row, and the row is narrower in proportion than either
box, so each box is fitted by width: a length is drawn as large as Le Mans's
when it stands at the ratio of the two boxes' widths -- São Paulo's box, margin
included, is 1,087 m against Le Mans's 4,112 -- rounded to a tenth of a metre.
The margin is the one length not taken there: it is added to the box as well as
to what stands in it, so it stands at three tenths of Le Mans's and is part of
what every ratio is taken over. The mini-sector label lengths are in the record
because `Lengths` holds them, at the same ratio as the rest, and not because this
lap has mini-sectors to name: it has none.

`Compact` is three tenths of Le Mans's and has no measurement behind it -- the
same set COTA, Barcelona and Monza authored compact with. Nothing draws that
detail, and the compacts of these circuits are fitted on different axes, so there
is no one ratio to read it from. It is the set to measure when a compact tracker is
drawn.

-}
lengths : { compact : Circuit.Lengths, full : Circuit.Lengths }
lengths =
    { compact =
        { margin = 45
        , trackWidth = 6.6
        , pitLaneWidth = 4.2
        , startFinishLineExtension = 39
        , startFinishLineStrokeWidth = 9.6
        , sectorBoundaryOffset = 31.5
        , sectorBoundaryStrokeWidth = 12.6
        , carSize = 31.5
        , labels = Nothing
        }
    , full =
        { margin = 210
        , trackWidth = 4.2
        , pitLaneWidth = 2.6
        , startFinishLineExtension = 42.3
        , startFinishLineStrokeWidth = 5.8
        , sectorBoundaryOffset = 28.5
        , sectorBoundaryStrokeWidth = 8.5
        , carSize = 25.6
        , labels =
            Just
                { sectorRadius = 100.4
                , sectorFontSize = 44.9
                , miniSectorRadius = -44.9
                , miniSectorFontSize = 31.7
                , carRadius = 50.2
                , carFontSize = 37.0
                }
        }
    }


shape : Geometry -> Shape
shape geometry =
    Circuit.shapeOf geometry.frame geometry.centreline


pitLane : Geometry -> List Point
pitLane geometry =
    Circuit.pitLaneOf geometry.frame geometry.pitLane


{-| The map's intermediate lines, as far from the finish line as its record puts them.

Every season here is drawn with that map, the latest. Nothing here splits the lap finer: the feed carries no mini-sector times for this circuit, so a car between two of these lines is placed by the share of the time between them it has run.

-}
timingLines : Intermediates -> Shape -> TimingLines
timingLines map lap =
    { sectors =
        Sector.initialize
            (\sector ->
                case sector of
                    S1 ->
                        map.intermediate1

                    S2 ->
                        map.intermediate2

                    S3 ->
                        Shape.length lap
            )
    , miniSectors = SectorsOnly
    }
