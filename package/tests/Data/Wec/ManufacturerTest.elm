module Data.Wec.ManufacturerTest exposing (suite)

import Data.Wec.Manufacturer as Manufacturer
import Dict
import Expect
import Json.Decode as Decode
import Motorsport.Manufacturer exposing (unknown)
import Test exposing (Test, describe, test)


tableJson : String
tableJson =
    """
    { "manufacturers":
        [ { "name": "Aston Martin"
          , "color": "oklch(0.5 0.25 180)"
          , "logo": "/assets/manufacturer-logos/aston-martin.png"
          }
        , { "name": "Oreca", "color": "oklch(0.4 0.2 20)" }
        ]
    }
    """


table : Manufacturer.Manufacturers
table =
    Decode.decodeString Manufacturer.decoder tableJson
        |> Result.withDefault Dict.empty


suite : Test
suite =
    describe "Data.Wec.Manufacturer"
        [ describe "decoder"
            [ test "refuses a logo that is not a path" <|
                \_ ->
                    Decode.decodeString Manufacturer.decoder
                        """
                        { "manufacturers":
                            [ { "name": "Porsche", "color": "oklch(0.8 0 0)", "logo": 42 } ]
                        }
                        """
                        |> Expect.err
            ]
        , describe "fromName"
            [ test "draws a manufacturer the table names in its own color, with its logo" <|
                \_ ->
                    Manufacturer.fromName table { name = "Aston Martin", carNumber = "007" }
                        |> Expect.equal
                            { name = "Aston Martin"
                            , color = "oklch(0.5 0.25 180)"
                            , logoUrl = Just "/assets/manufacturer-logos/aston-martin.png"
                            }
            , test "leaves an entry with no logo its color and no image" <|
                \_ ->
                    Manufacturer.fromName table { name = "Oreca", carNumber = "22" }
                        |> Expect.equal
                            { name = "Oreca"
                            , color = "oklch(0.4 0.2 20)"
                            , logoUrl = Nothing
                            }
            , test "keeps the name of a manufacturer the table does not have, and gives it no logo" <|
                \_ ->
                    Manufacturer.fromName Dict.empty { name = "Oreca", carNumber = "22" }
                        |> Expect.all
                            [ .name >> Expect.equal "Oreca"
                            , .color >> Expect.notEqual unknown.color
                            , .logoUrl >> Expect.equal Nothing
                            ]
            , test "tells the cars of a manufacturer the table does not have apart" <|
                \_ ->
                    Manufacturer.fromName Dict.empty { name = "Oreca", carNumber = "22" }
                        |> .color
                        |> Expect.notEqual
                            (Manufacturer.fromName Dict.empty { name = "Oreca", carNumber = "23" }).color
            ]
        ]
