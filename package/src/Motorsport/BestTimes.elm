module Motorsport.BestTimes exposing
    ( Changes, empty, changesDecoder
    , Snapshot, Holder
    , at, timeOf
    )

{-| When each of the race's best times was set, what they stand at, and who set
them.

Nineteen records make up the baseline a timing screen rates against: the fastest
lap, three sectors and fifteen mini-sectors. Each is a
[`ChangePoints`](Internal-ChangePoints) over the moments it was beaten.

Which lap took which record is counted where the laps are, in `Round.Index`, and
arrives with the round's summary.

@docs Changes, empty, changesDecoder
@docs Snapshot, Holder
@docs at, timeOf

-}

import Decode.Driver as Driver
import Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Json.Decode as Decode exposing (Decoder, field)
import Json.Decode.Pipeline exposing (optional, required)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.MiniSector as MiniSector exposing (MiniSectors)
import Motorsport.Sector as Sector exposing (BySector)


{-| Every moment one of the race's records changed hands. What the times are at
a moment of the race is a [`Snapshot`](#Snapshot), read back out of this.
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

Read via [`at`](#at) these are the best times as they stood at that moment,
not as the race left them. `Nothing` is a record no lap has taken yet.

-}
type alias Snapshot =
    ByRecord (Maybe Holder)


{-| One value per record: the shape `Changes` and `Snapshot` share. Everything
done to the nineteen records goes through `map`, so they are enumerated once.
-}
type alias ByRecord a =
    { fastestLapTime : a
    , fastestSectors : BySector a
    , fastestMiniSectors : MiniSectors a
    }


map : (a -> b) -> ByRecord a -> ByRecord b
map f records =
    { fastestLapTime = f records.fastestLapTime
    , fastestSectors = Sector.initialize (\sector -> f (Sector.get sector records.fastestSectors))
    , fastestMiniSectors = MiniSector.map f records.fastestMiniSectors
    }


{-| No records taken yet. Read at any moment, every record comes back
`Nothing`.
-}
empty : Changes
empty =
    { fastestLapTime = ChangePoints.empty
    , fastestSectors = Sector.initialize (\_ -> ChangePoints.empty)
    , fastestMiniSectors = []
    }


{-| Read the records as the round's summary spells them out.

`miniSectors` is absent where the round's feed measured none, which is the
empty list here -- the same fact `track.miniSectors` being absent states.

-}
changesDecoder : Decoder Changes
changesDecoder =
    Decode.succeed ByRecord
        |> required "fastestLapTime" holdersDecoder
        |> required "sectors" (Decode.map3 BySector (field "s1" holdersDecoder) (field "s2" holdersDecoder) (field "s3" holdersDecoder))
        |> optional "miniSectors" miniSectorsDecoder []


miniSectorsDecoder : Decoder (MiniSectors (ChangePoints Holder))
miniSectorsDecoder =
    Decode.list
        (Decode.map2 (\name changes -> { name = name, value = changes })
            (field "name" Decode.string)
            (field "changes" holdersDecoder)
        )


holdersDecoder : Decoder (ChangePoints Holder)
holdersDecoder =
    Decode.map ChangePoints.fromList (Decode.list holderDecoder)


holderDecoder : Decoder ( Instant, Holder )
holderDecoder =
    Decode.map2 Tuple.pair
        (field "elapsed" Instant.decoder)
        (Decode.map4 Holder
            (field "time" durationDecoder)
            (field "carNumber" Decode.string)
            (field "lap" Decode.int)
            (field "driver" Driver.decoder)
        )


durationDecoder : Decoder Duration
durationDecoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case Duration.fromString str of
                    Just duration ->
                        Decode.succeed duration

                    Nothing ->
                        Decode.fail ("Expected a Duration, got \"" ++ str ++ "\"")
            )


{-| The records as they stood at a moment of the race: what a car crossing the
line then was rated against.
-}
at : { elapsed : Instant } -> Changes -> Snapshot
at clock =
    map (ChangePoints.valueAt clock.elapsed)


{-| One record as a plain time, for callers that want the number and not who set
it.
-}
timeOf : Maybe Holder -> Maybe Duration
timeOf =
    Maybe.map .time
