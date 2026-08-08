module Data.Wec exposing
    ( Event
    , eventDecoder
    )

{-|

@docs Event
@docs eventDecoder

-}

import Json.Decode as Decode exposing (Decoder, field, int, list, string)
import Json.Decode.Pipeline exposing (required)
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Race.Car as Car
import Motorsport.Wec.Class as Class
import Motorsport.Wec.Era exposing (Era)
import Motorsport.Wec.Manufacturer as Manufacturer


type alias Event =
    { name : String
    , startingGrid : List StartingGridItem
    }


type alias StartingGridItem =
    { position : Int
    , car : Car.Metadata
    }



-- DECODER


eventDecoder : Era -> Decoder Event
eventDecoder era =
    Decode.map2 Event
        (field "name" string)
        (field "startingGrid" (list (startingGridItemDecoder era)))


startingGridItemDecoder : Era -> Decoder StartingGridItem
startingGridItemDecoder era =
    Decode.map2 StartingGridItem
        (field "position" int)
        (field "car" (carMetadataDecoder era))


carMetadataDecoder : Era -> Decoder Car.Metadata
carMetadataDecoder era =
    Decode.succeed Car.Metadata
        |> required "carNumber" string
        |> required "drivers" (Decode.list driverDecoder)
        |> required "class" (string |> Decode.map (Class.fromString era))
        |> required "group" string
        |> required "team" string
        |> required "manufacturer" (string |> Decode.map Manufacturer.fromString)


driverDecoder : Decoder Driver
driverDecoder =
    Decode.map Driver.fromName
        (field "name" string)
