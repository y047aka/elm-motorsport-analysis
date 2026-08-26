module Data.Wec.ManufacturerTest exposing (suite)

import Css.Color exposing (oklch)
import Data.Wec.Manufacturer as Manufacturer
import Expect
import Json.Decode as Decode
import Motorsport.Manufacturer exposing (unknown)
import Test exposing (Test, describe, test)


tableJson : String
tableJson =
    """
    { "manufacturers":
        [ { "name": "Aston Martin"
          , "color": { "l": 0.5, "c": 0.25, "h": 180 }
          , "logo": "/assets/manufacturer-logos/aston-martin.png"
          }
        , { "name": "Oreca", "color": { "l": 0.4, "c": 0.2, "h": 20 } }
        ]
    }
    """


table : Manufacturer.Table
table =
    Decode.decodeString Manufacturer.decoder tableJson
        |> Result.withDefault Manufacturer.empty


suite : Test
suite =
    describe "Data.Wec.Manufacturer"
        [ describe "fromName"
            [ test "draws a manufacturer the table names in its own color, with its logo" <|
                \_ ->
                    Manufacturer.fromName table { name = "Aston Martin", carNumber = "007" }
                        |> Expect.equal
                            { name = "Aston Martin"
                            , color = oklch 0.5 0.25 180
                            , chartColor = oklch 0.5 0.25 180
                            , logoUrl = Just "/assets/manufacturer-logos/aston-martin.png"
                            }
            , test "leaves an entry with no logo its color and no image" <|
                \_ ->
                    Manufacturer.fromName table { name = "Oreca", carNumber = "22" }
                        |> Expect.equal
                            { name = "Oreca"
                            , color = oklch 0.4 0.2 20
                            , chartColor = oklch 0.4 0.2 20
                            , logoUrl = Nothing
                            }
            , test "keeps the name of a manufacturer the table does not have, and draws it neutral" <|
                \_ ->
                    Manufacturer.fromName Manufacturer.empty { name = "Oreca", carNumber = "22" }
                        |> Expect.all
                            [ .name >> Expect.equal "Oreca"
                            , .color >> Expect.equal unknown.color
                            , .logoUrl >> Expect.equal Nothing
                            ]
            , test "tells the cars of a manufacturer the table does not have apart" <|
                \_ ->
                    Manufacturer.fromName Manufacturer.empty { name = "Oreca", carNumber = "22" }
                        |> .chartColor
                        |> Expect.notEqual
                            (Manufacturer.fromName Manufacturer.empty { name = "Oreca", carNumber = "23" }).chartColor
            ]
        ]
