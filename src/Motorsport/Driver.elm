module Motorsport.Driver exposing (Driver, findCurrentDriver)


type alias Driver =
    { name : String
    , isCurrentDriver : Bool
    }


findCurrentDriver : List Driver -> Maybe Driver
findCurrentDriver drivers =
    drivers
        |> List.filter .isCurrentDriver
        |> List.head
