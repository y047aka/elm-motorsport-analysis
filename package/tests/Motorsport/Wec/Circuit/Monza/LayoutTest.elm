module Motorsport.Wec.Circuit.Monza.LayoutTest exposing (tests)

{-| The Monza drawing, built from the geometry bytes the app serves, read
through the app's own decoder.
-}

import Expect
import Motorsport.Circuit.Shape as Shape
import Motorsport.TestHelpers.Drawn as Drawn
import Motorsport.TestHelpers.LeMans as LeMansFixture
import Motorsport.TestHelpers.Map.Monza as MonzaMap
import Motorsport.TestHelpers.Survey.Monza as MonzaBytes
import Motorsport.Wec.Circuit.Layout exposing (Layout, MiniSectorLines(..))
import Motorsport.Wec.Circuit.Map as Map
import Motorsport.Wec.Circuit.Monza.Layout as Monza
import Test exposing (Test, describe, test)


tests : Test
tests =
    case ( Drawn.read Map.intermediatesDecoder Monza.decoder MonzaMap.text MonzaBytes.text, LeMansFixture.layout ) of
        ( Ok ( map, monza ), Ok reference ) ->
            let
                drawing =
                    Monza.layout map monza
            in
            describe "Motorsport.Wec.Circuit.Monza.Layout"
                [ test "the centreline runs forward round the lap, from the finish line" <|
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
