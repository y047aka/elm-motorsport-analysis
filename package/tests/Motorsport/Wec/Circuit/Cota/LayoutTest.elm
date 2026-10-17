module Motorsport.Wec.Circuit.Cota.LayoutTest exposing (tests)

import Expect
import Motorsport.Circuit.Shape as Shape
import Motorsport.Sector as Sector
import Motorsport.Wec.Circuit.Cota.Geometry as Geometry
import Motorsport.Wec.Circuit.Cota.Layout exposing (layout)
import Motorsport.Wec.Circuit.Layout exposing (MiniSectorLines(..))
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
        ]


increasing : List Float -> Bool
increasing xs =
    List.map2 (<) xs (List.drop 1 xs)
        |> List.all identity
