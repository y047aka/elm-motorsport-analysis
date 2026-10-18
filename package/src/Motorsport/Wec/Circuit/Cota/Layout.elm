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

Its `drawingScale` is 0.3: cars of 29 m, sector labels of 51 m and a margin of
210 m, which is where those lengths measure right against a lap drawn 1,825 m
across and 1,043 m tall, and fills four fifths of the drawing's width and two
thirds of its height.

-}
layout : Layout
layout =
    { shape = shape
    , pitLane = pitLane
    , timingLines = timingLines
    , drawingScale = 0.3
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
only. A sector's share of a lap is not a share of its distance, so the times
cannot say where a line stands; they say whether two rounds put the lines in the
same places. Read one class's best sector times as two distances round a lap of
this length: 2025 answers 1,143.8 and 3,245.5 m for a Hypercar and 1,194.6 and
3,316.8 m for an LMGT3, and 2026 answers 1,172.1 and 3,257.0, and 1,189.8 and
3,304.1. Two seasons, two grids, and 28 m between them -- a season answering
further than that has new lines, and needs a map read from them.

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
