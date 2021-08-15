module Data.RaceSummary exposing (RaceSummary, raceSummaryDecoder)

import Data.Driver exposing (Driver, driverDecoder)
import Json.Decode as Decode exposing (at, field, int, string)


type alias RaceSummary =
    { eventName : String
    , seasonName : String
    , lapTotal : Int
    , drivers : List Driver
    }


raceSummaryDecoder : Decode.Decoder RaceSummary
raceSummaryDecoder =
    Decode.map4 RaceSummary
        (at [ "event", "name" ] string)
        (at [ "season", "name" ] string)
        (field "lapTotal" int)
        (field "entries" (Decode.list driverDecoder))
