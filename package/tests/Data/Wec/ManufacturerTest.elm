module Data.Wec.ManufacturerTest exposing (suite)

import Css.Color exposing (oklch)
import Data.Wec.Manufacturer as Manufacturer
import Expect
import Motorsport.Manufacturer exposing (unknown)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Data.Wec.Manufacturer"
        [ describe "fromName"
            [ test "draws a named manufacturer in its own color, with its logo" <|
                \_ ->
                    Manufacturer.fromName { name = "Aston Martin", carNumber = "007" }
                        |> Expect.equal
                            { name = "Aston Martin"
                            , color = oklch 0.5 0.25 180
                            , chartColor = oklch 0.5 0.25 180
                            , logoUrl = Just "/assets/manufacturer-logos/aston-martin.png"
                            }
            , test "keeps the name of a manufacturer it does not name, and draws it neutral" <|
                \_ ->
                    Manufacturer.fromName { name = "Oreca", carNumber = "22" }
                        |> Expect.all
                            [ .name >> Expect.equal "Oreca"
                            , .color >> Expect.equal unknown.color
                            , .logoUrl >> Expect.equal Nothing
                            ]
            , test "tells the cars of a manufacturer it does not name apart" <|
                \_ ->
                    Manufacturer.fromName { name = "Oreca", carNumber = "22" }
                        |> .chartColor
                        |> Expect.notEqual (Manufacturer.fromName { name = "Oreca", carNumber = "23" }).chartColor
            ]
        ]
