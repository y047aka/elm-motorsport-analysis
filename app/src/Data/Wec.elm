module Data.Wec exposing
    ( Event, Track, StartingGrid, Basis(..), StartingGridEntry
    , eventDecoder
    )

{-|

@docs Event, Track, StartingGrid, Basis, StartingGridEntry
@docs eventDecoder

-}

import Json.Decode as Decode exposing (Decoder, field, float, int, list, string)
import Json.Decode.Pipeline exposing (optional, required)
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

`finishedAt` is the file's `race.duration`: how long the race ran, which is past
its `timeLimit`, the flag falling on a lap already under way. Playback runs to
the one and the regulations are measured against the other.

The `race` object also states the lap the leader finished on; the app works that
out for itself from the laps it goes on to load, and having it arrive twice would
only give the two answers a chance to disagree. `startedAt` has nothing showing a
time of day to read it yet. `season` is what picks the `Era` this decoder is
built with, so it has to be known before the request goes out.

`name` and `date` say which round this is, which the calendar had already
settled by telling the app which file to fetch. The file still states them, for
a reader who has only the file.

What is left is `track`, the whole of what this app knows about the circuit.

-}
type alias Event =
    { timeLimit : Instant
    , finishedAt : Instant
    , track : Track
    , startingGrid : StartingGrid
    }


{-| The circuit as the summary describes it: which way round it goes, and how
the lap divides. Handed to
[`Tracker.fromConfig`](Motorsport-Chart-Tracker#fromConfig) by whoever holds
both -- drawing it is not this module's business, and the field names are the
ones that function asks for.
-}
type alias Track =
    { direction : Direction
    , config : TrackConfig
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
        (field "race" (field "timeLimit" Instant.decoder))
        (field "race" (field "duration" Instant.decoder))
        (field "track" trackDecoder)
        (field "startingGrid" (startingGridDecoder era))


{-| Two keys the CLI leaves out when it has nothing to say, and `optional`
rather than `oneOf` is what tells that apart from a key it wrote wrong. `oneOf`
cannot: a `miniSectors` object one key short of fifteen would fall through to
the same branch a missing one does, and Le Mans would quietly draw as a circuit
that is not split that far.

Left out, the two mean different things. A round the CLI has not been told the
direction of has one all the same -- every circuit goes round one way or the
other -- so clockwise stands in, and that it is a guess is why the CLI does not
make it. A round with no `miniSectors` genuinely has none to draw.

Written wrong, both mean the same thing: this app and the CLI that wrote the
file disagree about the shape of it, which is not a thing to carry on from --
`sectors` beside them has always failed the event for it.

-}
trackDecoder : Decoder Track
trackDecoder =
    Decode.succeed
        (\direction sectors miniSectors ->
            { direction = direction
            , config = { sectors = sectors, miniSectors = miniSectors }
            }
        )
        |> optional "direction" directionDecoder Clockwise
        |> required "sectors" bySectorDecoder
        |> optional "miniSectors" (Decode.map MiniSectorShares byMiniSectorDecoder) NoMiniSectors


{-| Both spellings are matched, so a third one is a disagreement rather than a
silent half-turn. Unlike [`Basis`](#Basis), which carries what it did not
recognize, there is nowhere to put it: a track has to be drawn one way round or
the other.
-}
directionDecoder : Decoder Direction
directionDecoder =
    string
        |> Decode.andThen
            (\raw ->
                case raw of
                    "clockwise" ->
                        Decode.succeed Clockwise

                    "counter_clockwise" ->
                        Decode.succeed CounterClockwise

                    other ->
                        Decode.fail ("Unknown circuit direction: " ++ other)
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
