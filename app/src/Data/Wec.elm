module Data.Wec exposing
    ( Event, StartingGrid, Basis(..), StartingGridEntry
    , eventDecoder
    )

{-|

@docs Event, StartingGrid, Basis, StartingGridEntry
@docs eventDecoder

-}

import Json.Decode as Decode exposing (Decoder, field, int, list, nullable, string)
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


{-| The grid the file offers, and what it was worked out from.
-}
type alias StartingGrid =
    { basis : Basis
    , entries : List StartingGridEntry
    }


{-| What the order in `entries` came from.

The timing feed carries no qualifying result, so both readings the CLI can make
are estimates: `Lap1S1` orders the field by each car's first split, `Lap1Elapsed`
by the whole of its first lap. `Unknown` means the file could place nobody. A
basis naming a published grid would be the one exact answer, and none exists yet.

-}
type Basis
    = Lap1S1
    | Lap1Elapsed
    | Unknown


{-| Ordered by `position`, the cars with no position last.
-}
type alias StartingGridEntry =
    { position : Maybe Int
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

                    _ ->
                        Unknown
            )


startingGridEntryDecoder : Era -> Decoder StartingGridEntry
startingGridEntryDecoder era =
    Decode.map2 StartingGridEntry
        (field "position" (nullable int))
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
