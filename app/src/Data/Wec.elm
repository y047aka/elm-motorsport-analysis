module Data.Wec exposing
    ( Event
    , eventDecoder
    )

{-|

@docs Event
@docs eventDecoder

-}

import Json.Decode as Decode exposing (Decoder, field, int, list, string)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (required)
import Motorsport.Car as Car exposing (Status(..))
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver exposing (Driver)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.TimelineEvent as TimelineEvent exposing (TimelineEvent)


type alias Event =
    { name : String
    , startingGrid : List StartingGridItem
    , timelineEvents : List TimelineEvent
    }


type alias StartingGridItem =
    { position : Int
    , car : Car.Metadata
    }



-- DECODER


eventDecoder : Decoder Event
eventDecoder =
    Decode.map3 Event
        (field "name" string)
        (field "startingGrid" (list startingGridItemDecoder))
        (field "timelineEvents" (list TimelineEvent.decoder))


startingGridItemDecoder : Decoder StartingGridItem
startingGridItemDecoder =
    Decode.map2 StartingGridItem
        (field "position" int)
        (field "car" carMetadataDecoder)


classDecoder : Decoder Class
classDecoder =
    string |> Decode.andThen (Class.fromString >> Json.Decode.Extra.fromMaybe "Expected a Class")


carMetadataDecoder : Decoder Car.Metadata
carMetadataDecoder =
    Decode.succeed Car.Metadata
        |> required "carNumber" string
        |> required "drivers" (Decode.list driverDecoder)
        |> required "class" classDecoder
        |> required "group" string
        |> required "team" string
        |> required "manufacturer" (string |> Decode.map Manufacturer.fromString)


driverDecoder : Decoder Driver
driverDecoder =
    Decode.map Driver
        (field "name" string)
