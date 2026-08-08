module Data.Wec exposing
    ( Event, StartingGrid, Basis(..), StartingGridEntry
    , eventDecoder
    )

{-|

@docs Event, StartingGrid, Basis, StartingGridEntry
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
    , startingGrid : StartingGrid
    }


type alias StartingGrid =
    { basis : Basis
    , entries : List StartingGridEntry
    }


{-| What the order in `entries` came from, and so how much of it to believe. The
timing feed carries no qualifying result, so the CLI's readings are estimates.

`Unrecognized` is a basis written by a CLI newer than this app, carried through
as it was read. Collapsing it into `Unknown` would be a lie in the one direction
that matters, since the basis most likely to arrive next is a published grid —
the exact answer, read as the least trustworthy one.

-}
type Basis
    = Lap1S1
    | Lap1Elapsed
    | Unknown
    | Unrecognized String


{-| `position` runs 1..n over the entries, which are in that order.
-}
type alias StartingGridEntry =
    { position : Int
    , car : Car.Metadata
    }



-- DECODER


eventDecoder : Era -> Decoder Event
eventDecoder era =
    Decode.map2 Event
        (field "name" string)
        (field "startingGrid" (startingGridDecoder era))


startingGridDecoder : Era -> Decoder StartingGrid
startingGridDecoder era =
    Decode.map2 StartingGrid
        (field "basis" basisDecoder)
        (field "entries" (list (startingGridEntryDecoder era)))


basisDecoder : Decoder Basis
basisDecoder =
    string
        |> Decode.map
            (\raw ->
                case raw of
                    "lap1_s1" ->
                        Lap1S1

                    "lap1_elapsed" ->
                        Lap1Elapsed

                    "unknown" ->
                        Unknown

                    other ->
                        Unrecognized other
            )


startingGridEntryDecoder : Era -> Decoder StartingGridEntry
startingGridEntryDecoder era =
    Decode.map2 StartingGridEntry
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
