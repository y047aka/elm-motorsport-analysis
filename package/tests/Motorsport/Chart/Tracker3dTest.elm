module Motorsport.Chart.Tracker3dTest exposing (tests)

{-| The turnable map: how the reader's drag becomes an angle, and what the camera
does to the circuit's own metres.

The projection is tested because a camera goes wrong quietly; `projected` names the ways
it does.

-}

import Expect
import Fuzz exposing (Fuzzer)
import Motorsport.Chart.Tracker3d as Tracker3d
import Test exposing (Test, describe, fuzz2, test)


tests : Test
tests =
    describe "Motorsport.Chart.Tracker3d"
        [ describe "turning the map"
            [ test "a drag turns it by how far the pointer travelled" <|
                \_ ->
                    Expect.within (Expect.Absolute 0.0001)
                        (drag 200 0).azimuth
                        (Tracker3d.init.azimuth + 2 * ((drag 100 0).azimuth - Tracker3d.init.azimuth))
            , test "no turn reaches a map with no pointer held on it" <|
                \_ ->
                    (Tracker3d.update (Tracker3d.Turn 400 30) Tracker3d.init).azimuth
                        |> Expect.within (Expect.Absolute 0.0001) Tracker3d.init.azimuth
            , test "letting go keeps the angle the drag reached" <|
                \_ ->
                    let
                        released =
                            Tracker3d.update Tracker3d.Release (drag 120 -60)
                    in
                    Expect.all
                        [ \_ -> Expect.equal Nothing released.drag
                        , \_ -> Expect.within (Expect.Absolute 0.0001) released.azimuth ((drag 120 -60).azimuth)
                        ]
                        ()
            , fuzz2 Fuzz.float Fuzz.float "the eye stops short of the frame that turns the circuit over" <|
                \dx dy ->
                    Expect.within (Expect.Absolute 0.0001)
                        (clamp (degrees 4) (degrees 87) (drag dx dy).elevation)
                        (drag dx dy).elevation
            ]
        , describe "the projection"
            [ test "the band runs all the way round the lap" <|
                \_ ->
                    let
                        edges =
                            Tracker3d.band Tracker3d.init metres

                        n =
                            List.length edges // 2

                        outer =
                            List.take n edges

                        inner =
                            List.drop n edges
                    in
                    Expect.all
                        [ \_ -> Expect.equal (List.head outer) (List.head (List.reverse outer))
                        , \_ -> Expect.equal (List.head inner) (List.head (List.reverse inner))
                        ]
                        ()
            , test "the band is a surface and not a line" <|
                \_ ->
                    -- Looked at from above, where nothing is foreshortened: the two
                    -- edges stand a share of the lap's half apart, and the lap itself
                    -- two halves across.
                    let
                        edges =
                            Tracker3d.band overhead metres

                        n =
                            List.length edges // 2

                        widths =
                            List.map2
                                (\o i -> sqrt ((o.x - i.x) ^ 2 + (o.y - i.y) ^ 2))
                                (List.take n edges)
                                (List.reverse (List.drop n edges))

                        extent =
                            Maybe.withDefault 1 (List.maximum (List.map .x edges))
                                - Maybe.withDefault 0 (List.minimum (List.map .x edges))
                    in
                    Expect.greaterThan (extent * 0.005) (Maybe.withDefault 0 (List.maximum widths))
            , test "a drag to the right turns the azimuth the other way" <|
                \_ ->
                    -- The convention the map is turned by, and the one that goes back
                    -- unnoticed: the pointer's `x` and the azimuth run opposite.
                    Expect.lessThan Tracker3d.init.azimuth (drag 100 0).azimuth
            , test "the lap lands inside the box it is drawn in" <|
                \_ ->
                    insideBox Tracker3d.init
            , fuzz2 azimuths elevations "at any frame the map can be turned to" <|
                \az el ->
                    insideBox (turned az el)
            , test "the lap stands centred in that box" <|
                \_ ->
                    let
                        drawn =
                            Tracker3d.projected Tracker3d.init lap

                        centre =
                            bounds drawn

                        -- The fit takes the raised lap and the ground outline together,
                        -- and the outline stands a little under the lap it is drawn
                        -- beside: the ring's own middle is that much off the box's.
                        slack =
                            0.05
                    in
                    Expect.all
                        [ \_ -> Expect.within (Expect.Absolute (Tracker3d.box.w * slack)) ((centre.x0 + centre.x1) / 2) (Tracker3d.box.w / 2)
                        , \_ -> Expect.within (Expect.Absolute (Tracker3d.box.h * slack)) ((centre.y0 + centre.y1) / 2) (Tracker3d.box.h / 2)
                        ]
                        ()
            , test "looked at from above the map is the circuit, not its mirror image" <|
                \_ ->
                    Expect.greaterThan 0 (winding lap * winding (Tracker3d.projected overhead lap))
            , fuzz2 azimuths elevations "the lap winds the same way at every frame" <|
                \az el ->
                    Expect.greaterThan 0 (winding lap * winding (Tracker3d.projected (turned az el) lap))
            , test "the side standing near stands further out than the side standing far" <|
                \_ ->
                    let
                        shots =
                            Tracker3d.projected Tracker3d.init lap

                        middle =
                            { x = Tracker3d.box.w / 2, y = Tracker3d.box.h / 2 }

                        -- The eye opens south of the lap, so the corner drawn at its
                        -- bottom is the near one and the corner drawn at its top the far.
                        near =
                            List.drop 3 shots |> List.head |> Maybe.map (reach middle) |> Maybe.withDefault 0

                        far =
                            List.drop 1 shots |> List.head |> Maybe.map (reach middle) |> Maybe.withDefault 0
                    in
                    Expect.greaterThan far near
            , test "the road a dot is drawn on is round from above and thin from the side" <|
                \_ ->
                    -- A dot is a disc lying in the road's plane, so it shows that plane's
                    -- own flatness. The fit scales a drawing to its box and so leaves the
                    -- ratio of a figure's two spans alone, which is what is read here.
                    let
                        patch =
                            [ { x = 1000, y = 1040 }, { x = 1040, y = 1000 }, { x = 1000, y = 960 }, { x = 960, y = 1000 } ]

                        flatness model =
                            let
                                shots =
                                    Tracker3d.projected model patch

                                edge get =
                                    let
                                        values =
                                            List.map get shots
                                    in
                                    Maybe.withDefault 0 (List.maximum values)
                                        - Maybe.withDefault 0 (List.minimum values)

                                wide =
                                    edge .x

                                tall =
                                    edge .y
                            in
                            min wide tall / max wide tall

                        grazing =
                            turned Tracker3d.init.azimuth (degrees 4)
                    in
                    Expect.greaterThan (flatness grazing) (flatness overhead)
            ]
        ]


{-| A press at the origin and one move: the model after a drag of `x`, `y` pixels.
-}
drag : Float -> Float -> Tracker3d.Model
drag x y =
    Tracker3d.update (Tracker3d.Turn x y) (Tracker3d.update (Tracker3d.Grab 0 0) Tracker3d.init)


overhead : Tracker3d.Model
overhead =
    turned Tracker3d.init.azimuth (degrees 86)


{-| The map opened at, turned to a given azimuth and elevation.
-}
turned : Float -> Float -> Tracker3d.Model
turned azimuth elevation =
    let
        opened =
            Tracker3d.init
    in
    { opened | azimuth = azimuth, elevation = elevation }


azimuths : Fuzzer Float
azimuths =
    Fuzz.map (\n -> degrees (toFloat (modBy 360 (abs n)))) Fuzz.int


elevations : Fuzzer Float
elevations =
    Fuzz.map (\n -> degrees (4 + toFloat (modBy 100 (abs n)) * 0.83)) Fuzz.int


{-| A lap drawn as the circuit's metres are drawn, `y` running south. The four corners
stand east, north, west and south of the middle.
-}
lap : List { x : Float, y : Float }
lap =
    [ { x = 1, y = 0 }, { x = 0, y = -1 }, { x = -1, y = 0 }, { x = 0, y = 1 } ]


{-| A lap authored the way a circuit's marks are: metres, a long way from the origin,
and a half of 2000. The band is a share of that half, so a drawing that offsets the
metres themselves instead of the share shows up against this and not against a lap
already two units across.
-}
metres : List { x : Float, y : Float }
metres =
    [ { x = 2000, y = 0 }, { x = 4000, y = 2000 }, { x = 2000, y = 4000 }, { x = 0, y = 2000 } ]


insideBox : Tracker3d.Model -> Expect.Expectation
insideBox model =
    Tracker3d.projected model lap
        |> Expect.all
            [ \shots -> Expect.equal True (List.all (\s -> 0 <= s.x && s.x <= Tracker3d.box.w) shots)
            , \shots -> Expect.equal True (List.all (\s -> 0 <= s.y && s.y <= Tracker3d.box.h) shots)
            , \shots -> Expect.equal True (List.all (\s -> s.x == s.x && s.y == s.y) shots)
            ]


bounds : List { a | x : Float, y : Float } -> { x0 : Float, x1 : Float, y0 : Float, y1 : Float }
bounds shots =
    { x0 = Maybe.withDefault 0 (List.minimum (List.map .x shots))
    , x1 = Maybe.withDefault 0 (List.maximum (List.map .x shots))
    , y0 = Maybe.withDefault 0 (List.minimum (List.map .y shots))
    , y1 = Maybe.withDefault 0 (List.maximum (List.map .y shots))
    }


{-| The shoelace sum: signed, so its sign says which way round the points run.
-}
winding : List { a | x : Float, y : Float } -> Float
winding points =
    case points of
        [] ->
            0

        first :: _ ->
            List.map2 (\p q -> p.x * q.y - q.x * p.y) points (List.drop 1 points ++ [ first ])
                |> List.sum


reach : { a | x : Float, y : Float } -> { b | x : Float, y : Float } -> Float
reach a b =
    sqrt ((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
