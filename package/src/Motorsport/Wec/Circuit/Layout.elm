module Motorsport.Wec.Circuit.Layout exposing
    ( Layout, TimingLines, MiniSectorLines(..)
    , Lengths, LabelLengths
    , shapeOf, pitLaneOf
    )

{-| One circuit as a map draws it: the lap, the pit lane beside it, and where
round the lap the lines it is timed at stand. This is what
[`Tracker.onCircuit`](Motorsport-Chart-Tracker#onCircuit) is handed, so it is the
whole of what the tracker knows about a circuit's shape.

The degrees OpenStreetMap surveyed are held by each circuit's own `Geometry`
module; the projection into drawing metres happens here, once, so that every
circuit is drawn to the same tenth of a metre.

@docs Layout, TimingLines, MiniSectorLines
@docs Lengths, LabelLengths
@docs shapeOf, pitLaneOf

-}

import Motorsport.Circuit.Geodesy exposing (Frame, project)
import Motorsport.Circuit.Shape as Shape exposing (Mark, Point, Shape)
import Motorsport.Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans exposing (ByMiniSector)


{-| The circuit as the tracker draws it.

`lengths` is what the drawing is made at, per detail: see
[`Lengths`](#Lengths).

-}
type alias Layout =
    { shape : Shape
    , pitLane : List Point
    , timingLines : TimingLines
    , lengths : { compact : Lengths, full : Lengths }
    }


{-| How far round the lap, in metres, each stretch of it ends: where the line it
is timed to stands.
-}
type alias TimingLines =
    { sectors : BySector Float
    , miniSectors : MiniSectorLines
    }


{-| Whether the circuit's map places lines finer than its three sectors.
`SectorsOnly` is a circuit whose timing is never measured that far; a `Nothing`
inside `LeMansMiniSectors` is a line the map gives no distance for. Having no
lines at all is a different answer from having fifteen, most of which the map
leaves no distance for.

[`MiniSectorShares`](Motorsport-Chart-Tracker-Config#MiniSectorShares) is the
same question asked of a round's timing rather than of its circuit, and
[`lapScale`](Motorsport-Chart-Tracker-Config#lapScale) is where the two answers
are read together.

-}
type MiniSectorLines
    = SectorsOnly
    | LeMansMiniSectors (ByMiniSector (Maybe Float))


{-| The lengths one detail of a circuit's drawing is made at, in metres on the
ground: the `viewBox` margin the labels stand off in, the width of the ribbon the
lap and pit lane are stroked at, the start/finish line and sector boundaries,
and the diameter of a car.

They are written per circuit because they are measured on one circuit's ground.
A car marker of 97 m reads right against a lap 13.6 km round and 5.4 km tall and
swallows one 5.5 km round and 1 km tall, and no single number mends a lap whose
width-to-height ratio differs from the first lap's -- a wide-to-tall 1.75 against
0.5 -- since a car marker, a margin and a font want three different things of
it. So each circuit writes its own set for each detail it is drawn at, and
[`Tracker`](Motorsport-Chart-Tracker) draws from whatever set it is handed. The
chart's own ring, which no circuit is measured against, has lengths of its own
beside this in that module.

`labels` is `Nothing` at a detail that draws no names, rather than a set of
lengths nothing reads.

-}
type alias Lengths =
    { margin : Float
    , trackWidth : Float
    , pitLaneWidth : Float
    , startFinishLineExtension : Float
    , startFinishLineStrokeWidth : Float
    , sectorBoundaryOffset : Float
    , sectorBoundaryStrokeWidth : Float
    , carSize : Float
    , labels : Maybe LabelLengths
    }


{-| How far from the line it names a name stands, and the font it is set in, all
in metres. Positive stands outwards from the lap, negative inwards: a
mini-sector's name is set inside the lap it names.
-}
type alias LabelLengths =
    { sectorRadius : Float
    , sectorFontSize : Float
    , miniSectorRadius : Float
    , miniSectorFontSize : Float
    , carRadius : Float
    , carFontSize : Float
    }


{-| The lap's centreline as a line on the ground, from the degrees it was
surveyed at and the distances those degrees were stretched to.
-}
shapeOf : Frame -> List { a | lat : Float, lon : Float, metres : Float } -> Shape
shapeOf frame surveyed =
    Shape.fromMarks (List.map (mark frame) surveyed)


{-| The pit lane as a line on the ground. No car is ever placed on it.
-}
pitLaneOf : Frame -> List { a | lat : Float, lon : Float } -> List Point
pitLaneOf frame surveyed =
    List.map (drawn frame) surveyed


mark : Frame -> { a | lat : Float, lon : Float, metres : Float } -> Mark
mark frame point =
    let
        place =
            drawn frame point
    in
    { x = place.x
    , y = place.y
    , metres = point.metres
    }


drawn : Frame -> { a | lat : Float, lon : Float } -> Point
drawn frame place =
    let
        metres =
            project frame { lat = place.lat, lon = place.lon }
    in
    { x = tenth metres.x
    , y = tenth metres.y
    }


{-| The survey's own resolution: a tenth of a metre.

Where a mini-sector's name is written turns on which way the line goes at its
point, and that reading has a threshold in it, so a drawing carried to the last
digit of a projection can move a name by its own width.

-}
tenth : Float -> Float
tenth value =
    toFloat (round (value * 10)) / 10
