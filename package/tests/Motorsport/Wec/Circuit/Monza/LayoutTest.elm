module Motorsport.Wec.Circuit.Monza.LayoutTest exposing (tests)

{-| The Monza drawing, built from the geometry bytes the app serves, read
through the app's own decoder.
-}

import Expect
import Json.Decode as Decode exposing (Decoder)
import Motorsport.Circuit.Shape as Shape
import Motorsport.Sector as Sector exposing (Sector(..))
import Motorsport.TestHelpers.LeMans as LeMansFixture
import Motorsport.TestHelpers.Survey.Monza as MonzaBytes
import Motorsport.Wec.Circuit.Geometry exposing (Geometry)
import Motorsport.Wec.Circuit.Layout exposing (Layout, MiniSectorLines(..))
import Motorsport.Wec.Circuit.Monza.Layout as Monza
import Test exposing (Test, describe, test)


tests : Test
tests =
    case ( read Monza.decoder MonzaBytes.text, LeMansFixture.layout ) of
        ( Ok monza, Ok reference ) ->
            let
                drawing =
                    Monza.layout monza
            in
            describe "Motorsport.Wec.Circuit.Monza.Layout"
                [ test "the lap is the length the circuit measures it at" <|
                    \_ ->
                        Shape.length drawing.shape
                            |> Expect.within (Expect.Absolute 0.05) 5793.0
                , test "the centreline runs forward round the lap, from the finish line" <|
                    \_ ->
                        List.map .metres monza.centreline
                            |> Expect.all
                                [ List.head >> Expect.equal (Just 0)
                                , increasing >> Expect.equal True
                                ]
                , test "the line closes on itself" <|
                    \_ ->
                        ( List.head monza.centreline, List.head (List.reverse monza.centreline) )
                            |> Expect.all
                                [ \( first, last ) -> Maybe.map .lat first |> Expect.equal (Maybe.map .lat last)
                                , \( first, last ) -> Maybe.map .lon first |> Expect.equal (Maybe.map .lon last)
                                ]
                , test "the sectors end where the 2026 map puts its intermediates" <|
                    \_ ->
                        Sector.values drawing.timingLines.sectors
                            |> Expect.equal [ 2055, 3727, Shape.length drawing.shape ]
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

        ( monzaRead, leMansRead ) ->
            test "the geometry the app serves decodes" <|
                \_ ->
                    problems [ monzaRead ] ++ problems [ leMansRead ]
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
        monza =
            this.lengths.full

        leMans =
            reference.lengths.full

        names =
            case ( monza.labels, leMans.labels ) of
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
    [ ( "trackWidth", monza.trackWidth / leMans.trackWidth )
    , ( "pitLaneWidth", monza.pitLaneWidth / leMans.pitLaneWidth )
    , ( "startFinishLineExtension", monza.startFinishLineExtension / leMans.startFinishLineExtension )
    , ( "startFinishLineStrokeWidth", monza.startFinishLineStrokeWidth / leMans.startFinishLineStrokeWidth )
    , ( "sectorBoundaryOffset", monza.sectorBoundaryOffset / leMans.sectorBoundaryOffset )
    , ( "sectorBoundaryStrokeWidth", monza.sectorBoundaryStrokeWidth / leMans.sectorBoundaryStrokeWidth )
    , ( "carSize", monza.carSize / leMans.carSize )
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
