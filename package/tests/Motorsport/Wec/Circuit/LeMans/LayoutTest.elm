module Motorsport.Wec.Circuit.LeMans.LayoutTest exposing (tests)

{-| The Le Mans drawing, built from the geometry bytes the app serves and the map record its bundle carries, read through the app's own decoders.
-}

import Expect
import Motorsport.Circuit.Shape as Shape
import Motorsport.Sector as Sector
import Motorsport.TestHelpers.LeMans as LeMansFixture
import Motorsport.Wec.Circuit.Layout exposing (MiniSectorLines(..))
import Motorsport.Wec.Circuit.LeMans as LeMans
import Motorsport.Wec.Circuit.LeMans.Layout as LeMansLayout
import Test exposing (Test, describe, test)


tests : Test
tests =
    case ( LeMansFixture.map, LeMansFixture.geometry ) of
        ( Ok map, Ok leMans ) ->
            let
                drawing =
                    LeMansLayout.layout map leMans
            in
            describe "Motorsport.Wec.Circuit.LeMans.Layout"
                [ test "the lap is the length Al Kamel measures it at" <|
                    \_ ->
                        Shape.length drawing.shape
                            |> Expect.within (Expect.Absolute 0.05) 13625.7
                , test "the centreline runs forward round the lap, from the finish line" <|
                    \_ ->
                        List.map .metres leMans.centreline
                            |> Expect.all
                                [ List.head >> Expect.equal (Just 0)
                                , increasing >> Expect.equal True
                                ]
                , test "the line closes on itself" <|
                    \_ ->
                        ( List.head leMans.centreline, List.head (List.reverse leMans.centreline) )
                            |> Expect.all
                                [ \( first, last ) -> Maybe.map .lat first |> Expect.equal (Maybe.map .lat last)
                                , \( first, last ) -> Maybe.map .lon first |> Expect.equal (Maybe.map .lon last)
                                ]
                , test "the sectors end where the 2026 map puts its intermediates" <|
                    \_ ->
                        Sector.values drawing.timingLines.sectors
                            |> Expect.equal [ 1900.7, 7672.13, Shape.length drawing.shape ]
                , test "the map's lines stand in the order a car reaches them" <|
                    \_ ->
                        ( increasing (Sector.values drawing.timingLines.sectors)
                        , increasing (List.filterMap identity (distances drawing.timingLines.miniSectors))
                        )
                            |> Expect.equal ( True, True )
                , test "the lengths it is drawn at are the ones the tracker was measured at" <|
                    \_ ->
                        -- The reference set: every other circuit's lengths are read as
                        -- a fraction of these, and a Le Mans snapshot moves with any of
                        -- them.
                        drawing.lengths
                            |> Expect.equal
                                { compact =
                                    { margin = 150
                                    , trackWidth = 22
                                    , pitLaneWidth = 14
                                    , startFinishLineExtension = 130
                                    , startFinishLineStrokeWidth = 32
                                    , sectorBoundaryOffset = 105
                                    , sectorBoundaryStrokeWidth = 42
                                    , carSize = 105
                                    , labels = Nothing
                                    }
                                , full =
                                    { margin = 700
                                    , trackWidth = 16
                                    , pitLaneWidth = 10
                                    , startFinishLineExtension = 160
                                    , startFinishLineStrokeWidth = 22
                                    , sectorBoundaryOffset = 108
                                    , sectorBoundaryStrokeWidth = 32
                                    , carSize = 97
                                    , labels =
                                        Just
                                            { sectorRadius = 380
                                            , sectorFontSize = 170
                                            , miniSectorRadius = -170
                                            , miniSectorFontSize = 120
                                            , carRadius = 190
                                            , carFontSize = 140
                                            }
                                    }
                                }
                ]

        ( Err problem, _ ) ->
            test "the map record the bundle carries decodes" <|
                \_ ->
                    Expect.fail problem

        ( _, Err problem ) ->
            test "the geometry the app serves decodes" <|
                \_ ->
                    Expect.fail problem


increasing : List Float -> Bool
increasing xs =
    List.map2 (<) xs (List.drop 1 xs)
        |> List.all identity


{-| The lines the circuit places, whether it places fifteen or none.
-}
distances : MiniSectorLines -> List (Maybe Float)
distances lines =
    case lines of
        SectorsOnly ->
            []

        LeMansMiniSectors mini ->
            LeMans.values mini
