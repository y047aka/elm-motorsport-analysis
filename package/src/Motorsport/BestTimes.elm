module Motorsport.BestTimes exposing
    ( Changes, empty, changesDecoder
    , Snapshot, Holder
    , at, final, timeOf
    )

{-| When each of the race's best times was set, what they stand at, and who set
them.

Twenty records make up the baseline a timing screen rates against: the fastest
lap, three sectors, fifteen mini-sectors, and the slowest lap that the other end
of the scale is drawn against. Each is a
[`ChangePoints`](Motorsport-Internal-ChangePoints) over the moments it was
beaten, which is what keeps reading the baseline off a binary search rather than
twenty passes over every lap of the race.

Which lap took which record is counted where the laps are, in `Round.Index`, and
arrives with the round's summary.

The module sits beside [`Lap`](Motorsport-Lap) and [`Gap`](Motorsport-Gap)
rather than under either side it serves, because both sides need it and neither
owns it: [`Race`](Motorsport-Race) holds the records, and
[`Race.Snapshot`](Motorsport-Race-Snapshot) reads them back at the clock.

@docs Changes, empty, changesDecoder
@docs Snapshot, Holder
@docs at, final, timeOf

-}

import Json.Decode as Decode exposing (Decoder, field)
import Json.Decode.Pipeline exposing (required)
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (ByMiniSector)


{-| Every moment one of the race's records changed hands, collected once.

Named for the changes rather than the times, like the
[`StatusChanges`](Motorsport-Race-StatusChanges) it sits beside in a
[`Race`](Motorsport-Race): what the times actually are at a moment of the race
is a [`Snapshot`](#Snapshot), read back out of this.

-}
type alias Changes =
    ByRecord (ChangePoints Holder)


{-| A record and the lap that set it. `time` is the record itself -- the lap
time, the sector time, the mini-sector time -- not the time of the lap it was
set on, which for a sector record is a different number entirely.
-}
type alias Holder =
    { time : Duration
    , carNumber : String
    , lap : Int
    , driver : Driver
    }


{-| The records held still at one moment of the race -- the baseline a widget
rates times against, and the laps that set them.

Read mid-race via [`at`](#at) these are only the best times _so far_; only
[`final`](#final)'s answer is the race's actual best times. `Nothing` is a
record no lap has taken yet.

-}
type alias Snapshot =
    ByRecord (Maybe Holder)


{-| One value per record: the shape `Changes` and `Snapshot` share.

Everything this module does to the twenty records goes through `map`, so they
are enumerated in exactly one place.

-}
type alias ByRecord a =
    { fastestLapTime : a
    , slowestLapTime : a
    , fastestSectors : BySector a
    , fastestMiniSectors : ByMiniSector a
    }


map : (a -> b) -> ByRecord a -> ByRecord b
map f records =
    { fastestLapTime = f records.fastestLapTime
    , slowestLapTime = f records.slowestLapTime
    , fastestSectors = Sector.initialize (\sector -> f (Sector.get sector records.fastestSectors))
    , fastestMiniSectors = LeMans.initialize (\mini -> f (LeMans.get mini records.fastestMiniSectors))
    }


{-| No records taken yet. Read at any moment, every record comes back
`Nothing`.
-}
empty : Changes
empty =
    { fastestLapTime = ChangePoints.empty
    , slowestLapTime = ChangePoints.empty
    , fastestSectors = Sector.initialize (\_ -> ChangePoints.empty)
    , fastestMiniSectors = LeMans.initialize (\_ -> ChangePoints.empty)
    }


{-| Read the records as the round's summary spells them out.
-}
changesDecoder : Decoder Changes
changesDecoder =
    Decode.map4 ByRecord
        (field "fastestLapTime" holdersDecoder)
        (field "slowestLapTime" holdersDecoder)
        (field "sectors" (Decode.map3 BySector (field "s1" holdersDecoder) (field "s2" holdersDecoder) (field "s3" holdersDecoder)))
        (field "miniSectors" miniSectorsDecoder)


miniSectorsDecoder : Decoder (ByMiniSector (ChangePoints Holder))
miniSectorsDecoder =
    let
        miniSector key =
            required key holdersDecoder
    in
    Decode.succeed LeMans.ByMiniSector
        |> miniSector "scl2"
        |> miniSector "z4"
        |> miniSector "ip1"
        |> miniSector "z12"
        |> miniSector "sclc"
        |> miniSector "a7_1"
        |> miniSector "ip2"
        |> miniSector "a8_1"
        |> miniSector "sclb"
        |> miniSector "porin"
        |> miniSector "porout"
        |> miniSector "pitref"
        |> miniSector "scl1"
        |> miniSector "fordout"
        |> miniSector "fl"


holdersDecoder : Decoder (ChangePoints Holder)
holdersDecoder =
    Decode.map ChangePoints.fromList (Decode.list holderDecoder)


holderDecoder : Decoder ( Instant, Holder )
holderDecoder =
    Decode.map2 Tuple.pair
        (field "elapsed" Instant.decoder)
        (Decode.map4 Holder
            (field "time" Duration.decoder)
            (field "carNumber" Decode.string)
            (field "lap" Decode.int)
            (field "driver" (Decode.map Driver.fromName Decode.string))
        )


{-| The records as they stood at a moment of the race: what a car crossing the
line then was rated against.
-}
at : { elapsed : Instant } -> Changes -> Snapshot
at clock =
    map (ChangePoints.valueAt clock.elapsed)


{-| The records as the race left them, without having to name a time past the
end of it.
-}
final : Changes -> Snapshot
final =
    map ChangePoints.last


{-| One record as a plain time, for callers that want the number and not who set
it.
-}
timeOf : Maybe Holder -> Maybe Duration
timeOf =
    Maybe.map .time
