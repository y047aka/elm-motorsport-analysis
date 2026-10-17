module Motorsport.Wec.Circuit.Layout exposing
    ( Layout, TimingLines, MiniSectorLines(..)
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
@docs shapeOf, pitLaneOf

-}

import Motorsport.Circuit.Geodesy exposing (Frame, project)
import Motorsport.Circuit.Shape as Shape exposing (Mark, Point, Shape)
import Motorsport.Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans exposing (ByMiniSector)


{-| The circuit as the tracker draws it.

`drawingScale` is how big this circuit is against the circuit the tracker's
lengths were measured against. Those are metres on the ground -- a car marker,
a font, a margin -- so one set of them cannot serve Le Mans's lap, drawn 2.7 km
across and 5.4 km tall, and one drawn 1.8 across and 1.0 tall. It multiplies
every length in [`Tracker`](Motorsport-Chart-Tracker) at once, which is one
number for a drawing whose width and height may want different ones.

-}
type alias Layout =
    { shape : Shape
    , pitLane : List Point
    , timingLines : TimingLines
    , drawingScale : Float
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
