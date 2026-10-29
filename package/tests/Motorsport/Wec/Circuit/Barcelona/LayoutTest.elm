module Motorsport.Wec.Circuit.Barcelona.LayoutTest exposing (tests)

{-| The Barcelona drawing, built from the geometry bytes the app serves, read
through the app's own decoder.

The layout is handed a round's sector shares to place its lines with, because
this circuit publishes no line distances of its own; the shares here are the
2026 round's, the only round this drawing has been opened with. They are the
drawing's input, not its expectation: what is checked is the order and the
bounds of the lines, not where this season's times put them.
-}

import Expect
import Json.Decode as Decode exposing (Decoder)
import Motorsport.Chart.Tracker.Config exposing (Share)
import Motorsport.Circuit.Shape as Shape
import Motorsport.Sector as Sector exposing (BySector, Sector(..))
import Motorsport.TestHelpers.Survey.Barcelona as BarcelonaBytes
import Motorsport.TestHelpers.Survey.LeMans as LeMansBytes
import Motorsport.Wec.Circuit.Barcelona.Layout as Barcelona
import Motorsport.Wec.Circuit.Geometry exposing (Geometry)
import Motorsport.Wec.Circuit.Layout exposing (Layout, MiniSectorLines(..))
import Motorsport.Wec.Circuit.LeMans.Layout as LeMans
import Test exposing (Test, describe, test)


shares : BySector Share
shares =
    Sector.initialize
        (\sector ->
            case sector of
                S1 ->
                    { start = 0, share = 0.2919102149018926 }

                S2 ->
                    { start = 0.2919102149018926, share = 0.405803872145325 }

                S3 ->
                    { start = 0.6977140870472176, share = 0.3022859129527824 }
        )


tests : Test
tests =
    case ( read Barcelona.decoder BarcelonaBytes.text, read LeMans.decoder LeMansBytes.text ) of
        ( Ok barcelona, Ok leMans ) ->
            let
                drawing =
                    Barcelona.layout barcelona shares

                reference =
                    LeMans.layout 2025 leMans
            in
            describe "Motorsport.Wec.Circuit.Barcelona.Layout"
                [ test "the lap is the length the circuit measures it at" <|
                    \_ ->
                        Shape.length drawing.shape
                            |> Expect.within (Expect.Absolute 0.05) 4657.0
                , test "the centreline runs forward round the lap, from the finish line" <|
                    \_ ->
                        List.map .metres barcelona.centreline
                            |> Expect.all
                                [ List.head >> Expect.equal (Just 0)
                                , increasing >> Expect.equal True
                                ]
                , test "the line closes on itself" <|
                    \_ ->
                        ( List.head barcelona.centreline, List.head (List.reverse barcelona.centreline) )
                            |> Expect.all
                                [ \( first, last ) -> Maybe.map .lat first |> Expect.equal (Maybe.map .lat last)
                                , \( first, last ) -> Maybe.map .lon first |> Expect.equal (Maybe.map .lon last)
                                ]
                , test "the lines stand in the order a car reaches them" <|
                    \_ ->
                        Sector.values drawing.timingLines.sectors
                            |> increasing
                            |> Expect.equal True
                , test "no line stands past the end of the lap" <|
                    \_ ->
                        let
                            finishLine =
                                Shape.length drawing.shape
                        in
                        Sector.values drawing.timingLines.sectors
                            |> List.filter (\metres -> metres > finishLine)
                            |> Expect.equal []
                , test "the lap ends where the lap is" <|
                    \_ ->
                        Sector.get S3 drawing.timingLines.sectors
                            |> Expect.within (Expect.Absolute 0.05) (Shape.length drawing.shape)
                , test "the lap is not divided finer than its three sectors" <|
                    \_ ->
                        drawing.timingLines.miniSectors
                            |> Expect.equal SectorsOnly
                , describe "the lengths it is drawn at"
                    [ test "every length is drawn at Le Mans's size on the screen" <|
                        \_ ->
                            -- Both circuits are drawn in one box, and each box is fitted by its own
                            -- width: the row is narrower in proportion than either of them. A length
                            -- therefore reaches the same pixels at both circuits when it stands at
                            -- the ratio of the two widths. The margin is the one length held back at
                            -- three tenths of Le Mans's, since it is added to that width and so moves
                            -- what every ratio is taken over.
                            let
                                expected =
                                    boxWidth drawing / boxWidth reference
                            in
                            ratios drawing reference
                                |> List.filter (\( name, got ) -> abs (got - expected) > 0.01)
                                |> List.map (\( name, got ) -> name ++ " at " ++ String.fromFloat got ++ " against " ++ String.fromFloat expected)
                                |> Expect.equal []
                    ]
                ]

        ( barcelonaRead, leMansRead ) ->
            test "the geometry the app serves decodes" <|
                \_ ->
                    problems [ barcelonaRead, leMansRead ]
                        |> Expect.equal []


read : Decoder Geometry -> String -> Result String Geometry
read decoder text =
    Decode.decodeString decoder text
        |> Result.mapError Decode.errorToString


problems : List (Result String a) -> List String
problems reads =
    reads
        |> List.filterMap
            (\reading ->
                case reading of
                    Err problem ->
                        Just problem

                    Ok _ ->
                        Nothing
            )


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
ratios : Layout -> Layout -> List ( String, Float )
ratios this reference =
    let
        barcelona =
            this.lengths.full

        leMans =
            reference.lengths.full

        names =
            case ( barcelona.labels, leMans.labels ) of
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
    [ ( "trackWidth", barcelona.trackWidth / leMans.trackWidth )
    , ( "pitLaneWidth", barcelona.pitLaneWidth / leMans.pitLaneWidth )
    , ( "startFinishLineExtension", barcelona.startFinishLineExtension / leMans.startFinishLineExtension )
    , ( "startFinishLineStrokeWidth", barcelona.startFinishLineStrokeWidth / leMans.startFinishLineStrokeWidth )
    , ( "sectorBoundaryOffset", barcelona.sectorBoundaryOffset / leMans.sectorBoundaryOffset )
    , ( "sectorBoundaryStrokeWidth", barcelona.sectorBoundaryStrokeWidth / leMans.sectorBoundaryStrokeWidth )
    , ( "carSize", barcelona.carSize / leMans.carSize )
    ]
        ++ names


increasing : List Float -> Bool
increasing values =
    case values of
        [] ->
            True

        [ _ ] ->
            True

        first :: second :: rest ->
            first <= second && increasing (second :: rest)
