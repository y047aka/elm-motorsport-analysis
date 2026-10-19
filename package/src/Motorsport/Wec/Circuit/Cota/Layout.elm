module Motorsport.Wec.Circuit.Cota.Layout exposing (layout)

{-| The Circuit of the Americas as a map draws it: the lap, the pit lane beside
it, and where round the lap the lines it is timed at stand.

The record and the projection the degrees are drawn through are
[`Motorsport.Wec.Circuit.Layout`](Motorsport-Wec-Circuit-Layout), which every
circuit is drawn out of.

@docs layout

-}

import Motorsport.Circuit.Shape as Shape exposing (Point, Shape)
import Motorsport.Sector as Sector exposing (Sector(..))
import Motorsport.Wec.Circuit.Cota.Geometry as Geometry
import Motorsport.Wec.Circuit.Layout as Circuit exposing (Layout, MiniSectorLines(..), TimingLines)


{-| The circuit, on one set of timing lines for every season; see
[`timingLines`](#timingLines).

The lap runs counter-clockwise, as OpenStreetMap's own one-way tags say and as
the CLI answers the summary.

-}
layout : Layout
layout =
    { shape = shape
    , pitLane = pitLane
    , timingLines = timingLines
    , lengths = lengths
    }


{-| The lengths this drawing is measured at, in metres on the ground.

`Full` is measured so that its furniture comes to the same pixels as Le Mans's.
The tracker draws every circuit in one portrait row -- 286x525 where the visual
tests put it -- and both boxes are narrower in proportion than that row is wide, so
each is fitted by width: 0.127 px to the metre here, Le Mans's 0.070. A length is
then drawn as large as Le Mans's when it stands at 2245/4112, the ratio of the two
boxes' widths, which is where these come from, rounded to a tenth of a metre: a car
marked at 53 m, a car's number at 76.5 m, the lap stroked at 8.7 m.

The margin is the length that cannot be taken there with the rest, because it is
added to the box as well as to what stands in it: six tenths of Le Mans's
everything, margin included, and the lap comes back down to 189 px wide against the
232 it is drawn at now. `LayoutTest` holds every length but this one at the
ratio, since the margin is added to the box every ratio is taken over. The band left
under the lap -- two thirds of the row -- is the lap's own proportion, 1,825 m across
and 1,043 m tall in a row 0.545 wide-to-tall, and no length here touches it. The
mini-sector lengths are in the record because `Lengths` holds them, at the same
ratio as the rest, and not because this lap has mini-sectors to name: it has none.

`Compact` is three tenths of Le Mans's and has no measurement behind it. Nothing
draws that detail -- the app draws `Full` and nothing else -- and the two circuits'
compact boxes are fitted on different axes, Le Mans's 3012 by 5687 on its height and
this one's 1915 by 1133 on its width, so there is no one ratio to read it from. It
is the set to measure when a compact tracker is drawn.

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
        , trackWidth = 8.7
        , pitLaneWidth = 5.5
        , startFinishLineExtension = 87.4
        , startFinishLineStrokeWidth = 12
        , sectorBoundaryOffset = 59
        , sectorBoundaryStrokeWidth = 17.5
        , carSize = 53
        , labels =
            Just
                { sectorRadius = 207.6
                , sectorFontSize = 92.9
                , miniSectorRadius = -92.9
                , miniSectorFontSize = 65.6
                , carRadius = 103.8
                , carFontSize = 76.5
                }
        }
    }


shape : Shape
shape =
    Circuit.shapeOf Geometry.frame Geometry.centreline


pitLane : List Point
pitLane =
    Circuit.pitLaneOf Geometry.frame Geometry.pitLane


{-| The circuit's own track sector map: 1,313.2 m from the finish line to the
first intermediate line, 2,254.3 m further to the second, and 1,947.5 m home --
which add up to the 5,515 m centreline the same map gives, and are what
`Geometry` stretches OpenStreetMap's 5,502 m survey to. The distances the series
print for this circuit run 5,513 m, 2 m short of the map's own total; the map is
quoted because every line above is measured along it.

The map is the April 2021 event's, and every season here is drawn with it, since
no later map has been read. A season that moved its lines would be drawn with the
wrong boundaries, and would place every car wrong between them.

What a new season is checked against is the round's own splits, and for movement
only: `node app/scripts/check-timing-lines.mjs 2026/cota_6h --against 2025` reads
each class's fastest sector times as two distances round a lap of this length, and
judges how far apart the two seasons put the lines. A sector's share of a lap is
not a share of its distance, so the times cannot say where a line stands -- the
shares themselves place the first line 170 m from where this layout does -- they
say whether two rounds put the lines in the same places. 2025 answers 1,143.8 and
3,245.5 m for a Hypercar and 1,194.6 and 3,316.8 m for an LMGT3, and 2026 answers
1,172.1 and 3,257.0, and 1,189.8 and 3,304.1: two seasons, two grids, and 28 m
between them. How far apart is too far is the command's to say, not this drawing's.

Nothing here splits the lap finer: the feed carries no mini-sector times for
this round, so a car between two of these lines is placed by the share of the
time between them it has run. Le Mans has lines finer than these to place a car
at, and so is placed to a mini-sector rather than to a few hundred metres.

-}
timingLines : TimingLines
timingLines =
    { sectors =
        Sector.initialize
            (\sector ->
                case sector of
                    S1 ->
                        1313.2

                    S2 ->
                        3567.5

                    S3 ->
                        Shape.length shape
            )
    , miniSectors = SectorsOnly
    }
