module Motorsport.ManufacturerTest exposing (suite)

import Color
import Expect
import Motorsport.Manufacturer as Manufacturer exposing (Manufacturer(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Manufacturer"
        [ describe "fromString"
            [ test "converts known manufacturer strings" <|
                \_ ->
                    Expect.all
                        [ \_ -> Manufacturer.fromString "Alpine" |> Expect.equal Alpine
                        , \_ -> Manufacturer.fromString "Aston Martin" |> Expect.equal AstonMartin
                        , \_ -> Manufacturer.fromString "BMW" |> Expect.equal BMW
                        , \_ -> Manufacturer.fromString "Cadillac" |> Expect.equal Cadillac
                        , \_ -> Manufacturer.fromString "Corvette" |> Expect.equal Corvette
                        , \_ -> Manufacturer.fromString "Ferrari" |> Expect.equal Ferrari
                        , \_ -> Manufacturer.fromString "Ford" |> Expect.equal Ford
                        , \_ -> Manufacturer.fromString "Lexus" |> Expect.equal Lexus
                        , \_ -> Manufacturer.fromString "McLaren" |> Expect.equal McLaren
                        , \_ -> Manufacturer.fromString "Mercedes" |> Expect.equal Mercedes
                        , \_ -> Manufacturer.fromString "Peugeot" |> Expect.equal Peugeot
                        , \_ -> Manufacturer.fromString "Porsche" |> Expect.equal Porsche
                        , \_ -> Manufacturer.fromString "Toyota" |> Expect.equal Toyota
                        ]
                        ()
            , test "handles unknown manufacturer strings" <|
                \_ ->
                    Manufacturer.fromString "Unknown Brand"
                        |> Expect.equal Other
            , test "handles empty string" <|
                \_ ->
                    Manufacturer.fromString ""
                        |> Expect.equal Other
            ]
        , describe "toString"
            [ test "converts manufacturer to string" <|
                \_ ->
                    Expect.all
                        [ \_ -> Manufacturer.toString Alpine |> Expect.equal "Alpine"
                        , \_ -> Manufacturer.toString AstonMartin |> Expect.equal "Aston Martin"
                        , \_ -> Manufacturer.toString BMW |> Expect.equal "BMW"
                        , \_ -> Manufacturer.toString Cadillac |> Expect.equal "Cadillac"
                        , \_ -> Manufacturer.toString Corvette |> Expect.equal "Corvette"
                        , \_ -> Manufacturer.toString Ferrari |> Expect.equal "Ferrari"
                        , \_ -> Manufacturer.toString Ford |> Expect.equal "Ford"
                        , \_ -> Manufacturer.toString Lexus |> Expect.equal "Lexus"
                        , \_ -> Manufacturer.toString McLaren |> Expect.equal "McLaren"
                        , \_ -> Manufacturer.toString Mercedes |> Expect.equal "Mercedes"
                        , \_ -> Manufacturer.toString Peugeot |> Expect.equal "Peugeot"
                        , \_ -> Manufacturer.toString Porsche |> Expect.equal "Porsche"
                        , \_ -> Manufacturer.toString Toyota |> Expect.equal "Toyota"
                        , \_ -> Manufacturer.toString Other |> Expect.equal "Other"
                        ]
                        ()
            ]
        , describe "toColor"
            [ test "returns distinct colors for different manufacturers" <|
                \_ ->
                    let
                        colors =
                            [ Alpine, AstonMartin, BMW, Cadillac, Corvette, Ferrari, Ford, Lexus, McLaren, Mercedes, Peugeot, Porsche, Toyota ]
                                |> List.map Manufacturer.toColor
                    in
                    colors
                        |> List.length
                        |> Expect.equal 13
            , test "returns consistent color for same manufacturer" <|
                \_ ->
                    let
                        color1 =
                            Manufacturer.toColor Ferrari

                        color2 =
                            Manufacturer.toColor Ferrari
                    in
                    color1 |> Expect.equal color2
            , test "returns appropriate brand colors" <|
                \_ ->
                    let
                        ferrariColor =
                            Manufacturer.toColor Ferrari

                        ferrariRgba =
                            Color.toRgba ferrariColor
                    in
                    -- Ferrari should have reddish color
                    ferrariRgba.red |> Expect.greaterThan 0.5
            ]
        , describe "roundtrip conversion"
            [ test "fromString >> toString preserves known manufacturers" <|
                \_ ->
                    Expect.all
                        [ \_ -> "Alpine" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "Alpine"
                        , \_ -> "Aston Martin" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "Aston Martin"
                        , \_ -> "BMW" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "BMW"
                        , \_ -> "Cadillac" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "Cadillac"
                        , \_ -> "Corvette" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "Corvette"
                        , \_ -> "Ferrari" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "Ferrari"
                        , \_ -> "Ford" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "Ford"
                        , \_ -> "Lexus" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "Lexus"
                        , \_ -> "McLaren" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "McLaren"
                        , \_ -> "Mercedes" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "Mercedes"
                        , \_ -> "Peugeot" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "Peugeot"
                        , \_ -> "Porsche" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "Porsche"
                        , \_ -> "Toyota" |> Manufacturer.fromString |> Manufacturer.toString |> Expect.equal "Toyota"
                        ]
                        ()
            ]
        , describe "toColorWithFallback"
            [ test "uses manufacturer color for known manufacturers" <|
                \_ ->
                    let
                        ferrariColor =
                            Manufacturer.toColorWithFallback "123" Ferrari

                        expectedFerrariColor =
                            Manufacturer.toColor Ferrari
                    in
                    ferrariColor |> Expect.equal expectedFerrariColor
            , test "generates distinct colors for Other manufacturer based on car number" <|
                \_ ->
                    let
                        color1 =
                            Manufacturer.toColorWithFallback "1" Other

                        color2 =
                            Manufacturer.toColorWithFallback "2" Other
                    in
                    color1 |> Expect.notEqual color2
            , test "generates consistent colors for same car number with Other manufacturer" <|
                \_ ->
                    let
                        color1 =
                            Manufacturer.toColorWithFallback "123" Other

                        color2 =
                            Manufacturer.toColorWithFallback "123" Other
                    in
                    color1 |> Expect.equal color2
            ]
        ]
