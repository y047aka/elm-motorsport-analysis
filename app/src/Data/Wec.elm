module Data.Wec exposing
    ( Event, StartingGrid, Basis(..), StartingGridEntry
    , eventDecoder
    )

{-|

@docs Event, StartingGrid, Basis, StartingGridEntry
@docs eventDecoder

-}

import Json.Decode as Decode exposing (Decoder, field, float, int, list, string)
import Json.Decode.Pipeline exposing (required)
import Motorsport.Chart.Tracker.Config as Config exposing (MiniSectorShares(..), Share, TrackConfig)
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race.Car as Car
import Motorsport.Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans exposing (ByMiniSector)
import Motorsport.Wec.Class as Class
import Motorsport.Wec.Era exposing (Era)
import Motorsport.Wec.Manufacturer as Manufacturer


{-| `timeLimit` is when the chequered flag falls, taken out of the file's `race`
object. The CLI reads it off the last lap anyone completed, rounded down to the
hour, because a WEC round is scheduled in whole hours and the timing feed never
says which.

That object states three things beside it -- when the race started, how long it
actually ran, and the lap the leader finished on -- which are not decoded here.
The last two the app works out for itself from the laps it goes on to load, and
having them arrive twice would only give the two answers a chance to disagree;
the first has nothing showing a time of day to read it yet.

`track` is the circuit's proportions, worked out by the CLI off the whole file
and read here rather than derived again -- see
[`Tracker.Config`](Motorsport-Chart-Tracker-Config). The `season` the file also
states is not decoded: it is what picks the `Era` this decoder is built with, so
the app has to know it before the request goes out.

-}
type alias Event =
    { name : String
    , timeLimit : Instant
    , track : TrackConfig
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
    Decode.map4 Event
        (field "name" string)
        (field "race" (field "timeLimit" Instant.decoder))
        (field "track" trackDecoder)
        (field "startingGrid" (startingGridDecoder era))


{-| A round whose feed does not split the lap into mini-sectors leaves the key
out, rather than writing fifteen shares nothing can be placed against.
-}
trackDecoder : Decoder TrackConfig
trackDecoder =
    Decode.map2 TrackConfig
        (field "sectors" bySectorDecoder)
        (Decode.oneOf
            [ field "miniSectors" (Decode.map MiniSectorShares byMiniSectorDecoder)
            , Decode.succeed NoMiniSectors
            ]
        )


shareDecoder : Decoder Share
shareDecoder =
    Decode.map2 Share
        (field "start" float)
        (field "share" float)


bySectorDecoder : Decoder (BySector Share)
bySectorDecoder =
    Decode.succeed BySector
        |> required "s1" shareDecoder
        |> required "s2" shareDecoder
        |> required "s3" shareDecoder


byMiniSectorDecoder : Decoder (ByMiniSector Share)
byMiniSectorDecoder =
    Decode.succeed ByMiniSector
        |> required "scl2" shareDecoder
        |> required "z4" shareDecoder
        |> required "ip1" shareDecoder
        |> required "z12" shareDecoder
        |> required "sclc" shareDecoder
        |> required "a7_1" shareDecoder
        |> required "ip2" shareDecoder
        |> required "a8_1" shareDecoder
        |> required "sclb" shareDecoder
        |> required "porin" shareDecoder
        |> required "porout" shareDecoder
        |> required "pitref" shareDecoder
        |> required "scl1" shareDecoder
        |> required "fordout" shareDecoder
        |> required "fl" shareDecoder


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
