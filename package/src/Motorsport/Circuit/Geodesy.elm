module Motorsport.Circuit.Geodesy exposing (Coordinate, Frame, frame, project)

{-| A circuit is surveyed in degrees on the earth and drawn in metres on a plane:
[`project`](#project) is the turn from one to the other, through the circuit's
own `Frame`. The metres it comes out in are the drawing's -- the same metres
round the lap that the timing feed counts in.

The turn is equirectangular about one parallel of a sphere, which across the few
kilometres a circuit covers is wrong by far less than the metre a surveyed line is
simplified to. Degrees are WGS84, the datum GPS records are written in.

@docs Coordinate, Frame, frame, project

-}

import Motorsport.Circuit.Shape exposing (Point)


{-| A place on the earth: WGS84 degrees, north and east of Greenwich being
positive.
-}
type alias Coordinate =
    { lat : Float
    , lon : Float
    }


{-| One circuit's drawing metres: how far a degree comes to in each direction,
and the place the drawing's zero stands at. See [`frame`](#frame).
-}
type Frame
    = Frame
        { origin : Coordinate
        , north : Float
        , east : Float
        }


{-| The frame whose `x`/`y` are zero at `origin`, with the east-west scale taken
at `parallel` -- the latitude the circuit is surveyed about, which is where the
drawing neither stretches nor shrinks the ground it stands on. Metres come out
north up with `y` running south, the way every circuit is drawn.
-}
frame : { origin : Coordinate, parallel : Float } -> Frame
frame { origin, parallel } =
    let
        north =
            degrees 1 * 6371008.8
    in
    Frame
        { origin = origin
        , north = north
        , east = north * cos (degrees parallel)
        }


{-| Where a place on the earth falls in a circuit's metres: east along `x`,
south along `y`.

    leMans : Frame
    leMans =
        frame { origin = { lat = 47.9618722, lon = 0.2074582 }, parallel = 47.94364 }

    let
        finish =
            project leMans { lat = 47.9498718, lon = 0.2075404 }
    in
    ( round finish.x, round finish.y )

    --> ( 6, 1334 )

which is where the drawing puts the Circuit de la Sarthe's finish line, at
`{ x = 6.1, y = 1334.4 }`.

-}
project : Frame -> Coordinate -> Point
project (Frame { origin, north, east }) coordinate =
    { x = (coordinate.lon - origin.lon) * east
    , y = (origin.lat - coordinate.lat) * north
    }
