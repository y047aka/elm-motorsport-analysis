module Motorsport.Wec.Circuit.Cota.LayoutTest exposing (tests)

import Expect
import Motorsport.Circuit.Shape as Shape
import Motorsport.Sector as Sector
import Motorsport.Wec.Circuit.Cota.Geometry as Geometry
import Motorsport.Wec.Circuit.Cota.Layout exposing (layout)
import Motorsport.Wec.Circuit.Layout exposing (LabelLengths, Lengths, MiniSectorLines(..))
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
        , describe
            "the lengths it is drawn at"
            [ test "every one is three tenths of Le Mans's" <|
                \_ ->
                    List.append (moved .compact) (moved .full)
                        |> Expect.equal []
            , test "the detail that names no line at Le Mans names none here" <|
                \_ ->
                    Expect.equal layout.lengths.compact.labels Nothing
            ]
        ]


{-| The lengths of one detail that stand at other than three tenths of the
reference circuit's, by name. The tolerance is the last bit of a float and no
more: 97 * 0.3 is 29.099999999999998, which this circuit writes as 29.1, and a
length measured on its own rather than scaled would be off by hundreds of
thousandths at the least.
-}
moved : ({ compact : Lengths, full : Lengths } -> Lengths) -> List String
moved detail =
    let
        cota =
            detail layout.lengths

        leMans =
            detail (LeMans.layout 2025).lengths

        ratios =
            [ ( "margin", cota.margin / leMans.margin )
            , ( "trackWidth", cota.trackWidth / leMans.trackWidth )
            , ( "pitLaneWidth", cota.pitLaneWidth / leMans.pitLaneWidth )
            , ( "startFinishLineExtension", cota.startFinishLineExtension / leMans.startFinishLineExtension )
            , ( "startFinishLineStrokeWidth", cota.startFinishLineStrokeWidth / leMans.startFinishLineStrokeWidth )
            , ( "sectorBoundaryOffset", cota.sectorBoundaryOffset / leMans.sectorBoundaryOffset )
            , ( "sectorBoundaryStrokeWidth", cota.sectorBoundaryStrokeWidth / leMans.sectorBoundaryStrokeWidth )
            , ( "carSize", cota.carSize / leMans.carSize )
            ]
                ++ List.map
                        (\( name, cotaLength, leMansLength ) ->
                            ( name, cotaLength / leMansLength )
                        )
                        (nameLengths cota.labels leMans.labels)
    in
    ratios
        |> List.filter (\( _, ratio ) -> abs (ratio - 0.3) > 1.0e-9)
        |> List.map (\( name, ratio ) -> name ++ " at " ++ String.fromFloat ratio)


{-| The names' lengths, beside the reference circuit's. Which detail has names is
asserted apart, so only the two that both have them are divided here.
-}
nameLengths : Maybe LabelLengths -> Maybe LabelLengths -> List ( String, Float, Float )
nameLengths cota leMans =
    case ( cota, leMans ) of
        ( Just a, Just b ) ->
            [ ( "sectorRadius", a.sectorRadius, b.sectorRadius )
            , ( "sectorFontSize", a.sectorFontSize, b.sectorFontSize )
            , ( "miniSectorRadius", a.miniSectorRadius, b.miniSectorRadius )
            , ( "miniSectorFontSize", a.miniSectorFontSize, b.miniSectorFontSize )
            , ( "carRadius", a.carRadius, b.carRadius )
            , ( "carFontSize", a.carFontSize, b.carFontSize )
            ]

        _ ->
            []


increasing : List Float -> Bool
increasing xs =
    List.map2 (<) xs (List.drop 1 xs)
        |> List.all identity
