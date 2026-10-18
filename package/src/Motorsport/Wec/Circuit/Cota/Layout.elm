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


{-| Le Mans's lengths at three tenths, which is where a lap drawn 1,825 m across
and 1,043 m tall wants a car marker of 29 m, sector labels of 51 m and a margin
of 210 m: the lap then fills four fifths of its box's width and two thirds of its
height, where Le Mans fills two thirds and four fifths of its own box.

What the multiplier sets is the furniture's size on the screen and not the
drawing's: the box is fitted by width, so this lap comes out 286 px wide and 186
tall in the 286x525 row the visual tests give it, where Le Mans comes out 286 by
472 -- 0.127 px to the metre against Le Mans's 0.070. At three tenths a car is
3.7 px across and its number 5.3 px tall, against Le Mans's 6.8 and 9.8, and the
lap line is 0.6 px against 1.1. Som over six tenths would match Le Mans's on the
screen -- and leave the row's lower half empty all the same, since that is the
lap's own proportion and not the length of anything here. The margin is the one
length not to take there with the others: it is added to the box as well as to the
furniture, so scaled whole it brings the lap back down to 189 px wide against the
232 it is drawn at now.

The mini-sector lengths are three tenths of Le Mans's because the record holds
them, not because this lap has mini-sectors to name: it has none.

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
        , trackWidth = 4.8
        , pitLaneWidth = 3
        , startFinishLineExtension = 48
        , startFinishLineStrokeWidth = 6.6
        , sectorBoundaryOffset = 32.4
        , sectorBoundaryStrokeWidth = 9.6
        , carSize = 29.1
        , labels =
            Just
                { sectorRadius = 114
                , sectorFontSize = 51
                , miniSectorRadius = -51
                , miniSectorFontSize = 36
                , carRadius = 57
                , carFontSize = 42
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
