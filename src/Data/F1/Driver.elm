module Data.F1.Driver exposing (Driver, driverDecoder)

import Json.Decode as Decode exposing (field, string)


type alias Driver =
    { name : String
    , carNumber : String
    , shortCode : String
    , teamName : String
    , teamColor : String
    }


driverDecoder : Decode.Decoder Driver
driverDecoder =
    Decode.map5 Driver
        (field "driverName" string)
        (field "car" string)
        (field "driverShortCode" string)
        (field "teamName" string)
        (field "teamColour" string)
