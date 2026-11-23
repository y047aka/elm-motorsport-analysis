module Motorsport.Wec.Circuit.Fuji.LayoutTest exposing (tests)

{-| The Fuji drawing, built from the geometry bytes the app serves, read
through the app's own decoder.
-}

import Expect
import Motorsport.Circuit.Shape as Shape
import Motorsport.TestHelpers.Drawn as Drawn
import Motorsport.TestHelpers.LeMans as LeMansFixture
import Motorsport.TestHelpers.Map.Fuji as FujiMap
import Motorsport.TestHelpers.Survey.Fuji as FujiBytes
import Motorsport.Wec.Circuit.Fuji.Layout as Fuji
import Motorsport.Wec.Circuit.Layout exposing (Layout, MiniSectorLines(..))
import Motorsport.Wec.Circuit.Map as Map
import Test exposing (Test, describe, test)


tests : Test
tests =
    case ( Drawn.read Map.intermediatesDecoder Fuji.decoder FujiMap.text FujiBytes.text, LeMansFixture.layout ) of
        ( Ok ( map, fuji ), Ok reference ) ->
            let
                drawing =
                    Fuji.layout map fuji
            in
            describe "Motorsport.Wec.Circuit.Fuji.Layout"
                [ test "the centreline runs forward round the lap, from the finish line" <|
                    \_ ->
                        List.map .metres fuji.centreline
                            |> Expect.all
                                [ List.head >> Expect.equal (Just 0)
                                , increasing >> Expect.equal True
                                ]
                , test "the line closes on itself" <|
                    \_ ->
                        ( List.head fuji.centreline, List.head (List.reverse fuji.centreline) )
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

        ( fujiRead, leMansRead ) ->
            test "the geometry the app serves decodes" <|
                \_ ->
                    problems [ fujiRead ] ++ problems [ leMansRead ]
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
        fuji =
            this.lengths.full

        leMans =
            reference.lengths.full

        names =
            case ( fuji.labels, leMans.labels ) of
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
    [ ( "trackWidth", fuji.trackWidth / leMans.trackWidth )
    , ( "pitLaneWidth", fuji.pitLaneWidth / leMans.pitLaneWidth )
    , ( "startFinishLineExtension", fuji.startFinishLineExtension / leMans.startFinishLineExtension )
    , ( "startFinishLineStrokeWidth", fuji.startFinishLineStrokeWidth / leMans.startFinishLineStrokeWidth )
    , ( "sectorBoundaryOffset", fuji.sectorBoundaryOffset / leMans.sectorBoundaryOffset )
    , ( "sectorBoundaryStrokeWidth", fuji.sectorBoundaryStrokeWidth / leMans.sectorBoundaryStrokeWidth )
    , ( "carSize", fuji.carSize / leMans.carSize )
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
