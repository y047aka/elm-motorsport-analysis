module Motorsport.Wec.Circuit.LeMans.LayoutTest exposing (tests)

import Expect
import Motorsport.Circuit.Shape as Shape
import Motorsport.Sector as Sector
import Motorsport.Wec.Circuit.LeMans as LeMans
import Motorsport.Wec.Circuit.LeMans.Geometry as Geometry
import Motorsport.Wec.Circuit.LeMans.Layout exposing (layout)
import Test exposing (Test, describe, test)


tests : Test
tests =
    describe "Motorsport.Wec.Circuit.LeMans.Layout"
        [ test "the lap is the length Al Kamel measures it at" <|
            \_ ->
                Shape.length (layout 2025).shape
                    |> Expect.within (Expect.Absolute 0.05) 13625.7
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
                        [ \( first, last ) -> Maybe.map .x first |> Expect.equal (Maybe.map .x last)
                        , \( first, last ) -> Maybe.map .y first |> Expect.equal (Maybe.map .y last)
                        ]
        , test "every season's lines stand in the order a car reaches them" <|
            \_ ->
                [ 2024, 2025, 2026 ]
                    |> List.map
                        (\season ->
                            let
                                lines =
                                    (layout season).timingLines
                            in
                            increasing (Sector.values lines.sectors)
                                && increasing (List.filterMap identity (LeMans.values lines.miniSectors))
                        )
                    |> Expect.equal [ True, True, True ]
        ]


increasing : List Float -> Bool
increasing xs =
    List.map2 (<) xs (List.drop 1 xs)
        |> List.all identity
