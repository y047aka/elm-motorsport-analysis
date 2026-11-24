module Motorsport.Chart.Tracker3d exposing (Model, Msg(..), init, update, view, box, projected, band, perPixel)

{-| The circuit raised off the ground it was surveyed on and seen through a
perspective camera, so the side of the loop standing near comes out wide and the
side standing far narrow, and the reader turns it by dragging.

The lap keeps its own shape -- the same metres [`ground`](Motorsport-Chart-Tracker#ground)
hands the flat drawing -- and is set above the plane it was surveyed on. A circuit
whose geometry carries heights stands at them, its lowest point where every other lap
stands flat, and its heights drawn `steep` times over; one that carries none stands
flat. Nothing is added to the circuit: no height it does not have. What turns it is a
frame, and what draws it is SVG, projected point by point.

Everything the drawing measures is a share of the lap's own size, so one set of
lengths serves every circuit and the ring it falls back to.

@docs Model, Msg, init, update, view, box, projected, band, perPixel

-}

import Angle
import Camera3d exposing (Camera3d)
import Motorsport.Chart.Tracker as Tracker exposing (Track)
import Motorsport.Circuit.Shape as Shape exposing (Point)
import Motorsport.Race.Snapshot as Snapshot exposing (Snapshot)
import Motorsport.Wec.Class as Class
import Point2d
import Point3d exposing (Point3d)
import Point3d.Projection as Projection
import Quantity exposing (Unitless)
import Rectangle2d exposing (Rectangle2d)
import Svg exposing (Svg, circle, g, line, polygon, polyline, svg, text, text_)
import Svg.Attributes exposing (class, dominantBaseline, fill, points, stroke, strokeLinejoin, strokeWidth, textAnchor, transform, viewBox)



-- HOW THE MAP IS HELD


{-| How the map is looked at. The azimuth spins the map round the vertical and the
elevation lifts the eye towards overhead; together they are the whole pose -- there is no
scale to set, the drawing being fitted to its box.
-}
type alias Model =
    { azimuth : Float
    , elevation : Float
    }


{-| Turned a quarter from the flat map and lifted a little, so it reads as a thing
in space before it is touched.
-}
init : Model
init =
    { azimuth = -pi / 2
    , elevation = degrees 26
    }


{-| Roll the map towards the right by, and lift the eye towards overhead by, the radians
given.
-}
type Msg
    = Roll Float Float


{-| The azimuth runs the other way round from a roll towards the right: a thing rolled to
the right carries the side standing near to the right with it, and that is the azimuth
running down. The reversal is made here and nowhere else.
-}
update : Msg -> Model -> Model
update msg m =
    case msg of
        Roll roll rise ->
            { m | azimuth = m.azimuth - roll, elevation = lifted (m.elevation + rise) }


{-| The radians a pixel of the pointer's travel is worth.
-}
perPixel : Float
perPixel =
    degrees 0.45


{-| The eye's height above the plane the lap lies in. Overhead is the flat map
again; it stops short of straight down, where the frame turns over.
-}
lifted : Float -> Float
lifted =
    clamp (degrees 4) (degrees 87)


{-| The eye's distance from the lap, in the lap's own radii.

It is fixed because the distance is not free. It sets how much bigger the near side of
the lap is drawn than the far side -- a quarter at this distance -- and a car's drawn
size is scaled by that same depth while already carrying its class position at 10% a
place. The standing alone is therefore worth about two places of that encoding, and a
nearer eye would drown it. Zooming is another matter: the row is there to show the
whole lap.

-}
eyeDistance : Float
eyeDistance =
    8.2



-- THE BOX AND THE EYE


{-| Nothing claims a coordinate frame for the scene: the units are unitless and the
coordinates are nobody's.
-}
type alias Space =
    ()


{-| The screen the scene is projected onto: three across to one high, which is how a lap
turned towards the eye comes out.

The drawing is not kept to these proportions -- the fit reaches whatever box the map is
stood in, however the reader shaped it -- but every projected point is said against this
screen, and `projected` and `band` are read in its units.

-}
box : { w : Float, h : Float }
box =
    { w = 1800, h = 600 }


{-| The box the drawing is fitted into, from the box it is stood in on the page.

The width stays `box`'s own whatever the shape the reader made, so a stroke or a car
sized in these units keeps its thickness as the box is grown along that axis; only the
height follows the box, and the fit fills it. A box of another proportion then costs
nothing: the drawing is fitted to it rather than letterboxed inside it.

-}
frameOf : { width : Float, height : Float } -> { w : Float, h : Float }
frameOf { width, height } =
    { w = box.w, h = box.w * height / width }


{-| The screen the camera projects onto: `box` centred on the origin, so a projected
point's own coordinates say where it stands from the middle of the drawing. Its `y`
runs up; the drawing's runs down, and `project` is where the two are joined.
-}
screen : Rectangle2d Unitless Space
screen =
    Rectangle2d.from
        (Point2d.unitless (negate (box.w / 2)) (negate (box.h / 2)))
        (Point2d.unitless (box.w / 2) (box.h / 2))


camera : Model -> Camera3d Unitless Space
camera m =
    Camera3d.orbitZ
        { focalPoint = Point3d.origin
        , azimuth = Angle.radians m.azimuth
        , elevation = Angle.radians m.elevation
        , distance = Quantity.float eyeDistance
        , projection = Camera3d.Perspective
        , fov = Camera3d.angle (Angle.degrees 30)
        }


{-| Where a point of the scene lands on the screen, and how far from the eye it
stands. The depth is what the field is sorted by, and what every length is divided
by.
-}
type alias Shot =
    { x : Float
    , y : Float
    , depth : Float
    }


project : Camera3d Unitless Space -> Point3d Unitless Space -> Shot
project eye point =
    let
        ( x, y ) =
            Projection.toScreenSpace eye screen point |> Point2d.coordinates
    in
    { x = Quantity.toFloat x
    , y = negate (Quantity.toFloat y)
    , depth = Projection.depth eye point |> Quantity.toFloat
    }


{-| How many screen units one unit of the scene comes to at one depth: the
horizontal half of the projection, read off the frustum.
-}
atDepth : Camera3d Unitless Space -> Shot -> Float
atDepth eye shot =
    box.h / (2 * Camera3d.frustumSlope eye * shot.depth)



-- FITTING THE DRAWING TO ITS BOX


{-| The projected coordinates are centred on the origin, and the box is not: `k` and the
two offsets are what carry one into the other. `frame` is the box the drawing is fitted
into, kept beside the fit that reaches it so nothing downstream is told which box it is
drawing.
-}
type alias Place =
    { k : Float
    , dx : Float
    , dy : Float
    , frame : { w : Float, h : Float }
    }


fitOf : { w : Float, h : Float } -> List Shot -> Place
fitOf frame shots =
    case ( List.map .x shots, List.map .y shots ) of
        ( [], _ ) ->
            { k = 1, dx = 0, dy = 0, frame = frame }

        ( xs, ys ) ->
            let
                x0 =
                    Maybe.withDefault 0 (List.minimum xs)

                x1 =
                    Maybe.withDefault 0 (List.maximum xs)

                y0 =
                    Maybe.withDefault 0 (List.minimum ys)

                y1 =
                    Maybe.withDefault 0 (List.maximum ys)
            in
            { k =
                min (frame.w * room / max (x1 - x0) 0.001)
                    (frame.h * room / max (y1 - y0) 0.001)
            , dx = -(x0 + x1) / 2
            , dy = -(y0 + y1) / 2
            , frame = frame
            }


{-| The share of the box the drawing is let have.
-}
room : Float
room =
    0.94


place : Place -> Shot -> Shot
place { k, dx, dy, frame } shot =
    { x = frame.w / 2 + k * (shot.x + dx), y = frame.h / 2 + k * (shot.y + dy), depth = shot.depth }


lineTo : Place -> ( Shot, Shot ) -> ( Shot, Shot )
lineTo p ( a, b ) =
    ( place p a, place p b )


{-| The lap stood on the plane it is drawn on, turned to the way it is being looked at,
and the fit that scales it to the box. The eye comes out with it: a car is drawn at
the eye and sized by how far the eye already is.
-}
type alias Stance =
    { eye : Camera3d Unitless Space
    , size : Size
    , ground : List Shot
    , ribbon : List Shot
    , fit : Place
    }


stance : { w : Float, h : Float } -> Model -> List Lifted -> Stance
stance frame model points =
    let
        eye =
            camera model

        ring =
            ringOf points

        size =
            sizeOf ring

        ground =
            List.map (project eye << groundAt size) ring

        ribbon =
            List.map (project eye << raisedAt size) (bandOf size ring)

        marks =
            ground ++ ribbon

        -- The room a name needs over the lap: the topmost mark can carry a car, and what
        -- falls outside a viewBox is not drawn at all. Held at both ends, so the lap stays
        -- centred in its box and the room costs a little scale rather than the drawing
        -- sitting low in it.
        crown =
            case ( List.sortBy .y marks, List.sortBy .y marks |> List.reverse ) of
                ( peak :: _, last :: _ ) ->
                    let
                        rise =
                            nameRise eye peak
                    in
                    [ { peak | y = peak.y - rise }, { last | y = last.y + rise } ]

                _ ->
                    []
    in
    { eye = eye
    , size = size
    , ground = ground
    , ribbon = ribbon
    , fit =
        -- Never the cars: the field moving round the lap cannot breathe the drawing bigger
        -- and smaller between frames.
        fitOf frame (marks ++ crown)
    }


{-| Where the points of a circuit land in the drawing, in the box's own units.

The drawing is these points joined up, so this is where the two ways a camera goes
wrong show: a frame that turns the circuit over draws its mirror image, and a fit that
misses the box draws a lap running off the edge. Both still look like a track.

@docs projected

-}
projected : Model -> List Point -> List Shot
projected model points =
    let
        { ground, fit } =
            stance box model (List.map flat points)
    in
    List.map (place fit) ground


{-| The lap as the band it is drawn as: the outside edge and back round the inside, in
the box's own units.

@docs band

-}
band : Model -> List Point -> List Shot
band model points =
    let
        scene =
            stance box model (List.map flat points)
    in
    List.map (place scene.fit) scene.ribbon



-- THE SCENE


{-| Everything the drawing is made of, projected but not yet fitted: the points are
still the eye's own screen units, and `draw` scales them to the box.
-}
type alias Scene =
    { ground : List Shot
    , pit : { ground : List Shot, band : List Shot }
    , band : List Shot
    , risers : List ( Shot, Shot )
    , boundaries : List ( Shot, Shot )
    , finish : ( Shot, Shot )
    , labels : List ( Shot, Float, String )
    , cars : List Car
    }


{-| A car as the drawing needs it. `disc` is the two axes of the circle the dot is -- what
becomes of a step of the car's own radius along the circuit's `x`, and of one along its
`y` -- in the projection's units before the fit.
-}
type alias Car =
    { at : Shot
    , disc :
        { ux : Float
        , uy : Float
        , vx : Float
        , vy : Float
        }
    , radius : Float
    , colour : String
    , number : String
    , fontSize : Float
    }


{-| How far the lap stands above the plane it was surveyed on, how wide the band it
is drawn as, and how big a car: all shares of the lap's own half.
-}
lift : Float
lift =
    0.1


bandWidth : Float
bandWidth =
    0.03


{-| How many times over a circuit's heights are drawn. At any other figure than 1 they
are the one length here not drawn to scale, and the drawing has nothing yet that says so.
-}
steep : Float
steep =
    1


carSize : Float
carSize =
    0.024


{-| How the name over a car is sized and set: its em is `nameSize` dot radii, its line
stands `nameGap` ems over the top of the dot, and its glyphs reach `nameReach` ems above
the line.
-}
nameSize : Float
nameSize =
    1.7


nameGap : Float
nameGap =
    1.2


nameReach : Float
nameReach =
    0.5


{-| How far a name stands over the mark it is drawn at -- the gap and the reach the name
is set by, over the top of its dot. In the projection's units, before the fit. The names
carry no standing, so this is every name's height at the depth `shot` stands at.
-}
nameRise : Camera3d Unitless Space -> Shot -> Float
nameRise eye shot =
    let
        size =
            carSize * atDepth eye shot

        em =
            nameSize * size
    in
    size + (nameGap + nameReach) * em


labelOffset : Float
labelOffset =
    0.075


labelSize : Float
labelSize =
    0.045


view : { width : Float, height : Float } -> Model -> Track -> Snapshot -> Svg msg
view surface model shown standings =
    let
        g =
            Tracker.ground shown

        rising =
            Maybe.map (\relief height -> (height - relief.lowest) * steep) g.relief

        risesOf heights points =
            case ( rising, heights ) of
                ( Just rise, Just these ) ->
                    List.map2 (\p h -> { x = p.x, y = p.y, rise = rise h }) points these

                _ ->
                    List.map flat points

        lap =
            risesOf (Maybe.map .lap g.relief) g.lap

        { eye, size, ground, ribbon, fit } =
            stance (frameOf surface) model lap

        acrossBand : Float -> Lifted -> Shape.Position -> ( Shot, Shot )
        acrossBand width standing position =
            let
                out =
                    outward position

                side k =
                    project eye (raisedAt size { x = position.x + out.x * k * size.half, y = position.y + out.y * k * size.half, rise = standing.rise })
            in
            ( side width, side (negate width) )

        -- Where a place round the lap stands, and how high: a height between two of
        -- the lap's points is the one the line between them passes.
        onLap along =
            let
                position =
                    g.at along
            in
            ( { x = position.x
              , y = position.y
              , rise =
                    case ( rising, g.relief ) of
                        ( Just rise, Just relief ) ->
                            rise (relief.at along)

                        _ ->
                            0
              }
            , position
            )

        across width along =
            let
                ( standing, position ) =
                    onLap along
            in
            acrossBand width standing position

        pitLine =
            risesOf (Maybe.map .pitLane g.relief) g.pitLane

        pit =
            { ground = List.map (project eye << groundAt size) pitLine
            , band = List.map (project eye << raisedAt size) pitLine
            }

        cars =
            Snapshot.toList standings
                |> List.map
                    (\car ->
                        let
                            ( standing, position ) =
                                onLap (g.carAt car)

                            shot =
                                project eye (raisedAt size standing)

                            -- The dot is the ground the car stands on: a circle of the
                            -- car's own radius, drawn in the road's plane rather than on
                            -- the screen, so it follows the tilt of the road.
                            share =
                                carSize * carScale car.standing.positionInClass

                            wide =
                                share * atDepth eye shot

                            -- The dot carries the standing. A name shrunk a tenth a place
                            -- on top of the depth the car stands at is one the back of the
                            -- field cannot read, and it says nothing the dot has not said.
                            name =
                                carSize * atDepth eye shot * nameSize

                            inPlane axis =
                                project eye
                                    (raisedAt size
                                        { x = position.x + axis.x * share * size.half
                                        , y = position.y + axis.y * share * size.half
                                        , rise = standing.rise
                                        }
                                    )

                            fromCentre axis =
                                let
                                    here =
                                        inPlane axis
                                in
                                { x = here.x - shot.x, y = here.y - shot.y }
                        in
                        { at = shot
                        , disc =
                            { ux = (fromCentre { x = 1, y = 0 }).x
                            , uy = (fromCentre { x = 1, y = 0 }).y
                            , vx = (fromCentre { x = 0, y = 1 }).x
                            , vy = (fromCentre { x = 0, y = 1 }).y
                            }
                        , radius = wide
                        , colour = Class.toColor car.metadata.class
                        , number = car.metadata.carNumber
                        , fontSize = name
                        }
                    )

        scene =
            { ground = ground
            , pit = pit
            , band = ribbon
            , risers =
                every (riserStride (ringOf lap)) (ringOf lap)
                    |> List.map (\p -> ( project eye (groundAt size p), project eye (raisedAt size p) ))
            , boundaries = List.map (across (bandWidth / 2)) g.boundaries
            , finish = across (bandWidth * 0.8) g.finish
            , labels =
                List.map
                    (\{ at, label } ->
                        let
                            ( standing, position ) =
                                onLap at

                            out =
                                outward position

                            shot =
                                project eye (raisedAt size { x = position.x + out.x * labelOffset * size.half, y = position.y + out.y * labelOffset * size.half, rise = standing.rise })
                        in
                        ( shot, labelSize * atDepth eye shot, label )
                    )
                    g.sectors
            , cars = cars
            }
    in
    draw fit scene


{-| How much smaller a car behind the leader is drawn, as on the flat tracker.
-}
carScale : Int -> Float
carScale positionInClass =
    max 0.4 (1 - toFloat positionInClass * 0.1)


{-| The side of the line away from the infield. The lap is drawn with its own `y`
running down the drawing, so a lap driven clockwise has its infield to the right of
the way it runs.
-}
outward : Shape.Position -> Point
outward position =
    { x = negate position.heading.y, y = position.heading.x }


{-| How many marks stand between two risers.
-}
riserStride : List a -> Int
riserStride ring =
    max 1 (List.length ring // 120)


{-| Every `n`th item, from the first.
-}
every : Int -> List a -> List a
every n list =
    case list of
        [] ->
            []

        first :: rest ->
            first :: every n (List.drop (n - 1) rest)


{-| A point of a line, and how far above the plane the lap is set on it stands, in the
line's own metres and already drawn `steep` times over.
-}
type alias Lifted =
    { x : Float
    , y : Float
    , rise : Float
    }


flat : Point -> Lifted
flat p =
    { x = p.x, y = p.y, rise = 0 }


type alias Size =
    { centre : Point, half : Float }


{-| The lap as the two edges of a band, in the order a polygon wants them: one way
round the outside and back round the inside, which leaves the band itself filled and
the middle of the circuit empty.

The width is a share of the lap's half, and the marks are the circuit's own metres, so
the offset goes through the half: offset the metres themselves and the band is a hair
wide, and reads as a line rather than a surface.

Both edges run one mark past the end. The mark the lap closes at is a seam like any
other, and a polygon closes only the two ends of the list it is handed: leave the edges
short of it and the band has a wedge missing where the finish line stands.

-}
bandOf : Size -> List Lifted -> List Lifted
bandOf size ring =
    let
        seams =
            List.map2 Tuple.pair ring (normals ring) |> closed

        edge share =
            List.map (\( p, n ) -> offset (share * size.half) p n) seams
    in
    edge (bandWidth / 2) ++ List.reverse (edge (negate (bandWidth / 2)))


offset : Float -> Lifted -> Point -> Lifted
offset k p n =
    { p | x = p.x + n.x * k, y = p.y + n.y * k }


{-| The unit vector to the left of the way the lap runs, at each point, read off the
way it runs through that point.
-}
normals : List { a | x : Float, y : Float } -> List Point
normals ring =
    List.map2
        (\from to -> normalize { x = negate (to.y - from.y), y = to.x - from.x })
        (previous ring)
        (following ring)


normalize : Point -> Point
normalize v =
    let
        length =
            sqrt (v.x * v.x + v.y * v.y)
    in
    if length == 0 then
        { x = 0, y = 0 }

    else
        { x = v.x / length, y = v.y / length }


following : List a -> List a
following list =
    List.drop 1 list ++ List.take 1 list


previous : List a -> List a
previous list =
    List.take 1 (List.reverse list) ++ List.drop 1 list


{-| A circuit's mark list closes itself; the ring's does not.
-}
ringOf : List { a | x : Float, y : Float } -> List { a | x : Float, y : Float }
ringOf lap =
    case ( List.head lap, List.reverse lap |> List.head ) of
        ( Just first, Just last ) ->
            if abs (first.x - last.x) < 0.001 && abs (first.y - last.y) < 0.001 then
                List.take (List.length lap - 1) lap

            else
                lap

        _ ->
            lap


{-| The lap, put on a plane two units across centred on the origin. The drawing's
`y` runs south, and the plane's runs north, which is the way a map is looked at from
above: turned over, the circuit would be the wrong circuit -- the Circuit de la
Sarthe's right-hand turns coming out left-hand.
-}
groundAt : Size -> { a | x : Float, y : Float } -> Point3d Unitless Space
groundAt size p =
    planeAt 0 size p


{-| A point set on the lap: `lift` over the plane it was surveyed on, and its own rise
over that, in the plane's units.
-}
raisedAt : Size -> Lifted -> Point3d Unitless Space
raisedAt size p =
    planeAt (lift + p.rise / size.half) size p


planeAt : Float -> Size -> { a | x : Float, y : Float } -> Point3d Unitless Space
planeAt height size p =
    Point3d.unitless
        ((p.x - size.centre.x) / size.half)
        (negate ((p.y - size.centre.y) / size.half))
        height


sizeOf : List { a | x : Float, y : Float } -> Size
sizeOf points =
    let
        x0 =
            Maybe.withDefault 0 (List.minimum (List.map .x points))

        x1 =
            Maybe.withDefault 0 (List.maximum (List.map .x points))

        y0 =
            Maybe.withDefault 0 (List.minimum (List.map .y points))

        y1 =
            Maybe.withDefault 0 (List.maximum (List.map .y points))
    in
    { centre = { x = (x0 + x1) / 2, y = (y0 + y1) / 2 }
    , half = max 1 (max (x1 - x0) (y1 - y0) / 2)
    }



-- DRAWING


draw : Place -> Scene -> Svg msg
draw fit scene =
    svg
        [ viewBox ("0 0 " ++ String.fromFloat fit.frame.w ++ " " ++ String.fromFloat fit.frame.h)
        , class "h-full w-full"
        ]
        [ polysegment "oklch(1 0 0 / 0.14)" 3 (closed (List.map (place fit) scene.ground))
        , polysegment "oklch(1 0 0 / 0.08)" 3 (List.map (place fit) scene.pit.ground)
        , g [] (List.map (segment "oklch(1 0 0 / 0.12)" 2 fit) scene.risers)
        , polygon
            [ fill "oklch(1 0 0 / 0.13)"
            , stroke "oklch(1 0 0 / 0.4)"
            , strokeWidth "4"
            , strokeLinejoin "round"
            , points (pointsOf (List.map (place fit) scene.band))
            ]
            []
        , polysegment "oklch(1 0 0 / 0.35)" 3 (List.map (place fit) scene.pit.band)
        , g [] (List.map (segment "oklch(0.23 0 0)" 5 fit) scene.boundaries)
        , segment "#fff" 7 fit scene.finish
        , g [] (List.map (sector fit) scene.labels)
        , g []
            (scene.cars
                |> List.sortBy (.at >> .depth >> negate)
                |> List.map (carMarker fit)
            )
        ]


closed : List a -> List a
closed list =
    list ++ List.take 1 list


segment : String -> Float -> Place -> ( Shot, Shot ) -> Svg msg
segment colour width p ( a, b ) =
    let
        ( from, to ) =
            lineTo p ( a, b )
    in
    line
        [ Svg.Attributes.x1 (String.fromFloat from.x)
        , Svg.Attributes.y1 (String.fromFloat from.y)
        , Svg.Attributes.x2 (String.fromFloat to.x)
        , Svg.Attributes.y2 (String.fromFloat to.y)
        , stroke colour
        , strokeWidth (String.fromFloat width)
        ]
        []


polysegment : String -> Float -> List { a | x : Float, y : Float } -> Svg msg
polysegment colour width points_ =
    polyline
        [ stroke colour
        , strokeWidth (String.fromFloat width)
        , fill "none"
        , strokeLinejoin "round"
        , points (pointsOf points_)
        ]
        []


pointsOf : List { a | x : Float, y : Float } -> String
pointsOf =
    List.map (\pt -> String.fromFloat pt.x ++ "," ++ String.fromFloat pt.y)
        >> String.join " "


sector : Place -> ( Shot, Float, String ) -> Svg msg
sector fit ( shot, size, label ) =
    let
        placed =
            place fit shot
    in
    text_
        [ Svg.Attributes.x (String.fromFloat placed.x)
        , Svg.Attributes.y (String.fromFloat placed.y)
        , Svg.Attributes.fontSize (String.fromFloat (size * fit.k))
        , textAnchor "middle"
        , dominantBaseline "central"
        , fill "oklch(1 0 0 / 0.5)"
        ]
        [ text label ]


{-| The field, farthest first: the near cars are drawn over the far ones, as the
near side of the lap stands over the far side. A dot is the disc the car stands on, the
image of a circle lying in the road's own plane, so it goes thin as the eye comes down
to that plane and round again overhead. A name stands above its own car -- the name keeps
the screen's own uprightness, being read rather than driven -- and both grow and shrink
together with the depth the car stands at.
-}
carMarker : Place -> Car -> Svg msg
carMarker fit car =
    let
        placed =
            place fit car.at

        k =
            fit.k

        -- The unit circle taken through the road's two axes, and set down where the car
        -- stands. Nothing is solved for and nothing is floored: the affine image is the
        -- disc, and it is the disc at every pose or it is one at none.
        matrix =
            [ car.disc.ux * k
            , car.disc.uy * k
            , car.disc.vx * k
            , car.disc.vy * k
            , placed.x
            , placed.y
            ]
                |> List.map String.fromFloat
                |> String.join " "

        -- How high the dot reaches on the screen: the image of a circle sweeps its y out
        -- to the amplitude of the two axes' y. The name hangs off that, so it keeps its
        -- distance from the car as the road goes thin.
        high =
            sqrt ((car.disc.uy * k) ^ 2 + (car.disc.vy * k) ^ 2)

        -- How far above the car's mark its name's line stands. The fit holds room over the
        -- lap for this much -- see `nameRise`.
        above =
            high + car.fontSize * k * nameGap
    in
    g []
        [ circle
            [ Svg.Attributes.r "1"
            , transform ("matrix(" ++ matrix ++ ")")
            , fill car.colour
            ]
            []
        , text_
            [ Svg.Attributes.x (String.fromFloat placed.x)
            , Svg.Attributes.y (String.fromFloat (placed.y - above))
            , Svg.Attributes.fontSize (String.fromFloat (car.fontSize * k))
            , textAnchor "middle"
            , dominantBaseline "central"
            , fill "oklch(1 0 0 / 0.7)"
            ]
            [ text car.number ]
        ]
