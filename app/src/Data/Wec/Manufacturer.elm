module Data.Wec.Manufacturer exposing (Table, decoder, empty, fromName)

{-| Which manufacturers the timing feed names, and how each is drawn.

The table is `/static/manufacturers.json`, which is written by hand; nothing
generates it.

@docs Table, decoder, empty, fromName

-}

import Css exposing (Color)
import Css.Color exposing (oklch)
import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, field, float, string)
import Motorsport.Manufacturer exposing (Manufacturer, unknown)


{-| Keyed by the name the feed writes.
-}
type Table
    = Table (Dict String Entry)


type alias Entry =
    { color : Color
    , logoUrl : Maybe String
    }


{-| No manufacturers, rather than a guess at which: what there is before the
table arrives, and in place of one that could not be read.
-}
empty : Table
empty =
    Table Dict.empty


decoder : Decoder Table
decoder =
    field "manufacturers" (Decode.list entryDecoder)
        |> Decode.map (Dict.fromList >> Table)


entryDecoder : Decoder ( String, Entry )
entryDecoder =
    Decode.map3
        (\name color logoUrl -> ( name, { color = color, logoUrl = logoUrl } ))
        (field "name" string)
        (field "color" colorDecoder)
        (Decode.maybe (field "logo" string))


colorDecoder : Decoder Color
colorDecoder =
    Decode.map3 oklch
        (field "l" float)
        (field "c" float)
        (field "h" float)


{-| `carNumber` is what tells the cars of a manufacturer the table does not name
apart.
-}
fromName : Table -> { name : String, carNumber : String } -> Manufacturer
fromName (Table table) { name, carNumber } =
    case Dict.get name table of
        Just entry ->
            { name = name
            , color = entry.color
            , chartColor = entry.color
            , logoUrl = entry.logoUrl
            }

        Nothing ->
            { unknown
                | name = name
                , chartColor = generatedColor carNumber
            }


generatedColor : String -> Color
generatedColor carNumber =
    let
        carHash =
            String.toInt carNumber |> Maybe.withDefault 0

        hue =
            carHash * 37 |> modBy 360 |> toFloat
    in
    oklch 0.55 0.25 hue
