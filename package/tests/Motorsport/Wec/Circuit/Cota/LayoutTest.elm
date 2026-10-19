module Motorsport.Wec.Circuit.Cota.LayoutTest exposing (tests)

import Expect
import Motorsport.Circuit.Shape as Shape
import Motorsport.Sector as Sector
import Motorsport.Wec.Circuit.Cota.Geometry as Geometry
import Motorsport.Wec.Circuit.Cota.Layout exposing (layout)
import Motorsport.Wec.Circuit.Layout exposing (Layout, MiniSectorLines(..))
import Motorsport.Wec.Circuit.LeMans.Layout as LeMans
import Test exposing (Test, describe, test)


tests : Test
tests =
    describe "Motorsport.Wec.Circuit.Cota.Layout"
        [ test "the lap is the length the circuit measures it at" <|
            \_ ->
                Shape.length layout.shape
                    |> Expect.within (Expect.Absolute 0.05) 5515.0
        , test "the centreline runs forward round the lap, from the finish line" <|
            \_ ->
                List.map .metres Geometry.centreline
                    |> Expect.all
                        [ List.head >> Expect.equal (Just 0)
                        , increasing >> Expect.equal True
                        ]
        , test "the line closes on itself" <|
            \_ ->
                ( List.head Geometry.centreline, List.head (List.reverse Geometry.centreline) )
                    |> Expect.all
                        [ \( first, last ) -> Maybe.map .lat first |> Expect.equal (Maybe.map .lat last)
                        , \( first, last ) -> Maybe.map .lon first |> Expect.equal (Maybe.map .lon last)
                        ]
        , test "the lines stand in the order a car reaches them" <|
            \_ ->
                Sector.values layout.timingLines.sectors
                    |> increasing
                    |> Expect.equal True
        , test "no line stands past the end of the lap" <|
            \_ ->
                let
                    finishLine =
                        Shape.length layout.shape
                in
                Sector.values layout.timingLines.sectors
                    |> List.filter (\metres -> metres > finishLine)
                    |> Expect.equal []
        , test "the lap is not divided finer than its three sectors" <|
            \_ ->
                -- The timing feed carries no mini-sector times for this round.
                layout.timingLines.miniSectors
                    |> Expect.equal SectorsOnly
        , describe "the lengths it is drawn at"
            [ test "every length is drawn at Le Mans's size on the screen" <|
                \_ ->
                    -- Both circuits are drawn in one box, and each box is fitted by its own
                    -- width: the row is narrower in proportion than either of them. A length
                    -- therefore reaches the same pixels at both circuits when it stands at
                    -- the ratio of the two widths -- which is how these were set. The margin
                    -- is the one length held back at three tenths of Le Mans's, since it is
                    -- added to that width and so moves what every ratio is taken over.
                    let
                        expected =
                            boxWidth layout / boxWidth (LeMans.layout 2025)
                    in
                    ratios expected
                        |> List.filter (\( name, got ) -> abs (got - expected) > 0.01)
                        |> List.map (\( name, got ) -> name ++ " at " ++ String.fromFloat got ++ " against " ++ String.fromFloat expected)
                        |> Expect.equal []
            ]
        ]


{-| The circuit as drawn: the width the tracker fits it into, in metres on the
ground. `Tracker`'s own `bounds` plus the margin the labels stand off in, which is
the axis both of these circuits are fitted by.
-}
boxWidth : Layout -> Float
boxWidth this =
    let
        xs =
            List.map .x (Shape.marks this.shape) ++ List.map .x this.pitLane
    in
    case ( List.minimum xs, List.maximum xs ) of
        ( Just lo, Just hi ) ->
            hi - lo + 2 * this.lengths.full.margin

        _ ->
            0


{-| Every `Full` length beside the reference circuit's, as a ratio. The names are
the ones a failing length is reported by.
-}
ratios : Float -> List ( String, Float )
ratios expected =
    let
        cota =
            layout.lengths.full

        leMans =
            (LeMans.layout 2025).lengths.full

        names =
            case ( cota.labels, leMans.labels ) of
                ( Just a, Just b ) ->
                    [ ( "sectorRadius", a.sectorRadius / b.sectorRadius )
                    , ( "sectorFontSize", a.sectorFontSize / b.sectorFontSize )
                    , ( "miniSectorRadius", a.miniSectorRadius / b.miniSectorRadius )
                    , ( "miniSectorFontSize", a.miniSectorFontSize / b.miniSectorFontSize )
                    , ( "carRadius", a.carRadius / b.carRadius )
                    , ( "carFontSize", a.carFontSize / b.carFontSize )
                    ]

                _ ->
                    []
    in
    [ ( "trackWidth", cota.trackWidth / leMans.trackWidth )
    , ( "pitLaneWidth", cota.pitLaneWidth / leMans.pitLaneWidth )
    , ( "startFinishLineExtension", cota.startFinishLineExtension / leMans.startFinishLineExtension )
    , ( "startFinishLineStrokeWidth", cota.startFinishLineStrokeWidth / leMans.startFinishLineStrokeWidth )
    , ( "sectorBoundaryOffset", cota.sectorBoundaryOffset / leMans.sectorBoundaryOffset )
    , ( "sectorBoundaryStrokeWidth", cota.sectorBoundaryStrokeWidth / leMans.sectorBoundaryStrokeWidth )
    , ( "carSize", cota.carSize / leMans.carSize )
    ]
        ++ names


increasing : List Float -> Bool
increasing xs =
    List.map2 (<) xs (List.drop 1 xs)
        |> List.all identity
