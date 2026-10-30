module Motorsport.Wec.Circuit.Barcelona.Layout exposing (decoder, layout)

{-| The Circuit de Barcelona-Catalunya as a map draws it: the lap, the pit lane
beside it, and where round the lap the lines it is timed at stand.

The lap itself arrives as the served geometry -- `static/geometry/barcelona.geojson`,
decoded and checked by [`Motorsport.Wec.Circuit.Geometry`](Motorsport-Wec-Circuit-Geometry)
-- and what is written here is what the file cannot know: the drawing's lengths
and the lines the round is timed at. The record and the projection the degrees
are drawn through are
[`Motorsport.Wec.Circuit.Layout`](Motorsport-Wec-Circuit-Layout), which every
circuit is drawn out of.

@docs decoder, layout

-}

import Json.Decode exposing (Decoder)
import Motorsport.Chart.Tracker.Config exposing (Share)
import Motorsport.Circuit.Shape as Shape exposing (Point, Shape)
import Motorsport.Sector as Sector exposing (BySector, Sector(..))
import Motorsport.Wec.Circuit.Geometry as Geometry exposing (Geometry)
import Motorsport.Wec.Circuit.Layout as Circuit exposing (Layout, MiniSectorLines(..), TimingLines)


{-| Reading the served geometry against the 4,657 m the circuit's current
chicane layout measures, which is what the survey was stretched to.
-}
decoder : Decoder Geometry
decoder =
    Geometry.decoder { lapLength = 4657.0 }


{-| The circuit, on lines the round itself puts round the lap -- see
[`timingLines`](#timingLines).

The lap runs the direction its survey was chained in -- the word arrives with
the geometry, as OpenStreetMap's own one-way tags say it.
-}
layout : Geometry -> BySector Share -> Layout
layout geometry shares =
    let
        lap =
            shape geometry

        pit =
            pitLane geometry
    in
    { shape = lap
    , pitLane = pit
    , timingLines = timingLines lap shares
    , lengths = lengths
    }


{-| The lengths this drawing is measured at, in metres on the ground.

`Full` is measured so that its furniture comes to the same pixels as Le Mans's,
the way COTA's is. The tracker draws every circuit in one portrait row and each
box is narrower in proportion than that row is wide, so each is fitted by width:
a length is drawn as large as Le Mans's when it stands at the ratio of the two
boxes' widths -- Barcelona's box, margin included, is 1,379 m against Le Mans's
4,112 -- rounded to a tenth of a metre. The margin is the one length not taken
there: it is added to the box as well as to what stands in it, so it stands at
three tenths of Le Mans's and is part of what every ratio is taken over. The
mini-sector label lengths are in the record because `Lengths` holds them, at the
same ratio as the rest, and not because this lap has mini-sectors to name: it
has none.

`Compact` is three tenths of Le Mans's and has no measurement behind it -- the
same set COTA authored compact with. Nothing draws that detail, and the
compacts of these circuits are fitted on different axes, so there is no one
ratio to read it from. It is the set to measure when a compact tracker is drawn.
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
        , trackWidth = 5.4
        , pitLaneWidth = 3.4
        , startFinishLineExtension = 53.7
        , startFinishLineStrokeWidth = 7.4
        , sectorBoundaryOffset = 36.2
        , sectorBoundaryStrokeWidth = 10.7
        , carSize = 32.5
        , labels =
            Just
                { sectorRadius = 127.5
                , sectorFontSize = 57.0
                , miniSectorRadius = -57.0
                , miniSectorFontSize = 40.3
                , carRadius = 63.7
                , carFontSize = 47.0
                }
        }
    }


shape : Geometry -> Shape
shape geometry =
    Circuit.shapeOf geometry.frame geometry.centreline


pitLane : Geometry -> List Point
pitLane geometry =
    Circuit.pitLaneOf geometry.frame geometry.pitLane


{-| Where the lines the round is timed at stand on the surveyed lap.

This circuit publishes no distances for them -- the served geometry carries no
`sectors` -- so there is nothing here to author line metres from, and inventing
them would draw boundaries at a distance no one measured. What the round does
say is how its laps divided between the three stretches, which is the reading
the ring gives every undrawn round: a line stands where the round's own share
puts it, and every car between two of them is placed by the share of the time
between the lines it has run. The shape is surveyed; the lines are the round's,
and would move with a season that divided its laps differently.

If the circuit ever publishes the distances round its lap, they are authored in
the geometry project's config, travel in the served file, and replace this
derivation.

Nothing here splits the lap finer: the feed carries no mini-sector times for
this circuit, so a car between two of these lines is placed by the share of the
time between them it has run.
-}
timingLines : Shape -> BySector Share -> TimingLines
timingLines lap shares =
    let
        lapLength =
            Shape.length lap

        line sector =
            case sector of
                S3 ->
                    lapLength

                _ ->
                    let
                        stretch =
                            Sector.get sector shares
                    in
                    (stretch.start + stretch.share) * lapLength
    in
    { sectors = Sector.initialize line
    , miniSectors = SectorsOnly
    }
