module Data.Wec.Manufacturer exposing (Manufacturers, decoder, fromName)

{-| Which manufacturers the timing feed names, and how each is drawn.

The table is `/static/manufacturers.json`, which is written by hand.

@docs Manufacturers, decoder, fromName

-}

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, field, string)
import Json.Decode.Pipeline exposing (optional, required)
import Motorsport.Manufacturer exposing (Manufacturer, unknown)


{-| Keyed by the name the feed writes.
-}
type alias Manufacturers =
    Dict String Manufacturer


decoder : Decoder Manufacturers
decoder =
    field "manufacturers" (Decode.list entryDecoder)
        |> Decode.map Dict.fromList


entryDecoder : Decoder ( String, Manufacturer )
entryDecoder =
    Decode.succeed
        (\name color logoUrl ->
            ( name, { name = name, color = color, logoUrl = logoUrl } )
        )
        |> required "name" string
        |> required "color" string
        -- `optional` rather than `maybe`, which cannot tell a manufacturer with
        -- no logo from a `logo` written wrong.
        |> optional "logo" (Decode.map Just string) Nothing


{-| `carNumber` is what tells the cars of a manufacturer the table does not name
apart.
-}
fromName : Manufacturers -> { name : String, carNumber : String } -> Manufacturer
fromName manufacturers { name, carNumber } =
    case Dict.get name manufacturers of
        Just manufacturer ->
            manufacturer

        Nothing ->
            { unknown
                | name = name
                , color = generatedColor carNumber
            }


generatedColor : String -> String
generatedColor carNumber =
    let
        carHash =
            String.toInt carNumber |> Maybe.withDefault 0

        hue =
            carHash * 37 |> modBy 360 |> toFloat
    in
    "oklch(0.55 0.25 " ++ String.fromFloat hue ++ ")"
