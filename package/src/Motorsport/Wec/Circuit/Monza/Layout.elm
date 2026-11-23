module Motorsport.Wec.Circuit.Monza.Layout exposing (decoder, layout)

{-| The Autodromo Nazionale di Monza as a map draws it: the lap, the pit lane
beside it, and where round the lap the lines it is timed at stand.

The lap itself arrives as the served geometry -- `static/geometry/monza.geojson`,
decoded and checked by [`Motorsport.Wec.Circuit.Geometry`](Motorsport-Wec-Circuit-Geometry)
-- and what is written here is what the file cannot know: the drawing's lengths
and the lines the round is timed at. The record and the projection the degrees
are drawn through are
[`Motorsport.Wec.Circuit.Layout`](Motorsport-Wec-Circuit-Layout), which every
circuit is drawn out of.

The drawn finish line stands where the series' 2026 map puts it, as nearly as that map can be laid over the survey: OpenStreetMap holds no node at the line, so the place is authored, and the circuit project's config says how it was found.

@docs decoder, layout

-}

import Json.Decode exposing (Decoder)
import Motorsport.Circuit.Shape as Shape exposing (Point, Shape)
import Motorsport.Sector as Sector exposing (Sector(..))
import Motorsport.Wec.Circuit.Geometry as Geometry exposing (Geometry)
import Motorsport.Wec.Circuit.Layout as Circuit exposing (Layout, MiniSectorLines(..), TimingLines)


{-| Reading the served geometry against the 5,793 m the circuit measures its
lap at, which is what the survey was stretched to.
-}
decoder : Decoder Geometry
decoder =
    Geometry.decoder { lapLength = 5793.0 }


{-| The circuit, on the lines the series' 2026 map puts round the lap -- see
[`timingLines`](#timingLines).

The lap runs the direction its survey was chained in -- the word arrives with
the geometry, as OpenStreetMap's own one-way tags say it.
-}
layout : Geometry -> Layout
layout geometry =
    let
        lap =
            shape geometry

        pit =
            pitLane geometry
    in
    { shape = lap
    , pitLane = pit
    , timingLines = timingLines lap
    , lengths = lengths
    }


{-| The lengths this drawing is measured at, in metres on the ground.

`Full` is measured so that its furniture comes to the same pixels as Le Mans's,
the way COTA's and Barcelona's are. The tracker draws every circuit in one
portrait row, and the row is narrower in proportion than either box, so each box
is fitted by width: a length is drawn as large as Le Mans's when it stands at
the ratio of the two boxes' widths -- Monza's box, margin included, is 1,677 m
against Le Mans's 4,112 -- rounded to a tenth of a metre. The margin is the one
length not taken there: it is added to the box as well as to what stands in it,
so it stands at three tenths of Le Mans's and is part of what every ratio is
taken over. The mini-sector label lengths are in the record because `Lengths`
holds them, at the same ratio as the rest, and not because this lap has
mini-sectors to name: it has none.

`Compact` is three tenths of Le Mans's and has no measurement behind it -- the
same set COTA and Barcelona authored compact with. Nothing draws that detail,
and the compacts of these circuits are fitted on different axes, so there is no
one ratio to read it from. It is the set to measure when a compact tracker is
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
        , trackWidth = 6.5
        , pitLaneWidth = 4.1
        , startFinishLineExtension = 65.2
        , startFinishLineStrokeWidth = 9
        , sectorBoundaryOffset = 44
        , sectorBoundaryStrokeWidth = 13
        , carSize = 39.6
        , labels =
            Just
                { sectorRadius = 155
                , sectorFontSize = 69.3
                , miniSectorRadius = -69.3
                , miniSectorFontSize = 48.9
                , carRadius = 77.5
                , carFontSize = 57.1
                }
        }
    }


shape : Geometry -> Shape
shape geometry =
    Circuit.shapeOf geometry.frame geometry.centreline


pitLane : Geometry -> List Point
pitLane geometry =
    Circuit.pitLaneOf geometry.frame geometry.pitLane


{-| The series' 2026 map (`circuits/monza/map-2026.json`): i1 at 2,055 m from the finish line and i2 at 3,727 m, of the 5,793 m centreline the served geometry is stretched to.

Every season here is drawn with that map, the latest. Nothing here splits the lap finer: the feed carries no mini-sector times for this circuit, so a car between two of these lines is placed by the share of the time between them it has run.

-}
timingLines : Shape -> TimingLines
timingLines lap =
    { sectors =
        Sector.initialize
            (\sector ->
                case sector of
                    S1 ->
                        2055

                    S2 ->
                        3727

                    S3 ->
                        Shape.length lap
            )
    , miniSectors = SectorsOnly
    }
