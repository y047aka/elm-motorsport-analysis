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
import Motorsport.Chart.Tracker as Tracker
import Motorsport.Chart.Tracker.Config exposing (MiniSectorShares(..), Share, TrackConfig)
import Motorsport.Circuit.Direction exposing (Direction(..))
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race.Car as Car
import Motorsport.Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans exposing (ByMiniSector)
import Motorsport.Wec.Class as Class
import Motorsport.Wec.Era exposing (Era)
import Motorsport.Wec.Manufacturer as Manufacturer


{-| Less than the file states, and the omissions are the point.

The `race` object states how long the race actually ran and the lap the leader
finished on beside its `timeLimit`; the app works both out for itself from the
laps it goes on to load, and having them arrive twice would only give the two
answers a chance to disagree. `startedAt` has nothing showing a time of day to
read it yet. `season` is what picks the `Era` this decoder is built with, so it
has to be known before the request goes out.

What is left is `track`, the whole of what this app knows about the circuit.

-}
type alias Event =
    { name : String
    , timeLimit : Instant
    , track : Tracker.Track
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


{-| A round the CLI has not been told the direction of has one all the same --
every circuit goes round one way or the other -- so clockwise stands in for it.
That it is a guess is exactly why the CLI does not make it, and why the app has
to.
-}
trackDecoder : Decoder Tracker.Track
trackDecoder =
    Decode.map2 (\direction config -> Tracker.fromConfig { direction = direction, config = config })
        (Decode.oneOf
            [ field "direction" directionDecoder
            , Decode.succeed Clockwise
            ]
        )
        (Decode.map2 TrackConfig
            (field "sectors" bySectorDecoder)
            (Decode.oneOf
                [ field "miniSectors" (Decode.map MiniSectorShares byMiniSectorDecoder)
                , Decode.succeed NoMiniSectors
                ]
            )
        )


directionDecoder : Decoder Direction
directionDecoder =
    string
        |> Decode.map
            (\raw ->
                if raw == "counter_clockwise" then
                    CounterClockwise

                else
                    Clockwise
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
