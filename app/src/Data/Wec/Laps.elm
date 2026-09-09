module Data.Wec.Laps exposing
    ( RawLap, RawMiniSector
    , fromJsonl
    , attach
    )

{-|

@docs RawLap, RawMiniSector
@docs fromJsonl
@docs attach

-}

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, int, string)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (optional, required)
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Internal.Jsonl as Jsonl
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (ByMiniSector)


type alias RawLap =
    { carNumber : String
    , driverName : String
    , lapNumber : Int
    , position : Int
    , lapTime : Duration
    , sectors : BySector (Maybe Duration)
    , miniSectors : Maybe (ByMiniSector RawMiniSector)
    , elapsed : Instant
    , pitTime : Maybe Duration
    }


{-| One mini-sector of one lap as the file spells it:
[`Lap.MiniSectorTime`](Motorsport-Lap#MiniSectorTime) without the baseline,
which is [`attach`](#attach)'s to add.
-}
type alias RawMiniSector =
    { time : Maybe Duration
    , elapsedInLap : Maybe Duration
    }



-- DECODE


{-| Reads the laps file, which holds one lap per line rather than one array.
-}
fromJsonl : String -> Result String (List RawLap)
fromJsonl =
    Jsonl.decode rawLapDecoder


rawLapDecoder : Decoder RawLap
rawLapDecoder =
    Decode.succeed RawLap
        |> required "carNumber" string
        |> required "driverName" string
        |> required "lapNumber" int
        |> required "position" int
        |> required "lap" (Decode.field "time" durationDecoder)
        |> required "sectors" sectorsDecoder
        |> optional "miniSectors" (Decode.map Just miniSectorsDecoder) Nothing
        |> required "elapsed" Instant.decoder
        |> required "pitTime" optionalDurationDecoder


sectorsDecoder : Decoder (BySector (Maybe Duration))
sectorsDecoder =
    Decode.succeed BySector
        |> required "s1" sectorTimeDecoder
        |> required "s2" sectorTimeDecoder
        |> required "s3" sectorTimeDecoder


sectorTimeDecoder : Decoder (Maybe Duration)
sectorTimeDecoder =
    Decode.field "time" optionalDurationDecoder


{-| The mini-sector counterpart, on the rounds whose feed splits the lap that
far. Every key is `optional`: the CLI drops a mini-sector it has neither a time
nor a running total for, so a key short of fifteen is a mini-sector the feed
says nothing about rather than a file of the wrong shape.
-}
miniSectorsDecoder : Decoder (ByMiniSector RawMiniSector)
miniSectorsDecoder =
    let
        miniSector key =
            optional key miniSectorDecoder { time = Nothing, elapsedInLap = Nothing }
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


{-| `elapsed` on the wire is what a [`Lap`](Motorsport-Lap) calls
`elapsedInLap`: the running total from the line, not the race clock
`Lap.elapsed` carries.
-}
miniSectorDecoder : Decoder RawMiniSector
miniSectorDecoder =
    Decode.succeed RawMiniSector
        |> required "time" optionalDurationDecoder
        |> required "elapsed" optionalDurationDecoder


durationDecoder : Decoder Duration
durationDecoder =
    string |> Decode.andThen (Duration.fromString >> Json.Decode.Extra.fromMaybe "Expected a Duration")


optionalDurationDecoder : Decoder (Maybe Duration)
optionalDurationDecoder =
    string
        |> Decode.map
            (\s ->
                if String.isEmpty s then
                    Nothing

                else
                    Duration.fromString s
            )



-- ATTACH


{-| Attach raw laps to cars.

Per car: groups raws by `carNumber`, sorts by `lapNumber`, and accumulates
best lap / sector times.

-}
attach : List RawLap -> List Car -> List Car
attach rawLaps cars =
    let
        lapsByCarNumber : Dict CarNumber (List Lap)
        lapsByCarNumber =
            rawLaps
                |> groupBy .carNumber
                |> Dict.map (\_ raws -> finalizeCarLaps raws)
    in
    cars
        |> List.map
            (\car ->
                { car
                    | laps =
                        Dict.get car.metadata.carNumber lapsByCarNumber
                            |> Maybe.withDefault []
                }
            )


groupBy : (a -> comparable) -> List a -> Dict comparable (List a)
groupBy keyFn list =
    List.foldr
        (\item acc ->
            let
                key =
                    keyFn item

                existing =
                    Dict.get key acc |> Maybe.withDefault []
            in
            Dict.insert key (item :: existing) acc
        )
        Dict.empty
        list


finalizeCarLaps : List RawLap -> List Lap
finalizeCarLaps raws =
    raws
        |> List.sortBy .lapNumber
        |> List.foldl accumulate ( bestsInit, [] )
        |> Tuple.second
        |> List.reverse


type alias Bests =
    { lap : Maybe Duration
    , sectors : BySector (Maybe Duration)
    , miniSectors : ByMiniSector (Maybe Duration)
    }


bestsInit : Bests
bestsInit =
    { lap = Nothing
    , sectors = Sector.initialize (always Nothing)
    , miniSectors = LeMans.initialize (always Nothing)
    }


minMaybe : Maybe Duration -> Maybe Duration -> Maybe Duration
minMaybe current new =
    case ( current, new ) of
        ( Nothing, _ ) ->
            new

        ( _, Nothing ) ->
            current

        ( Just c, Just n ) ->
            Just (Basics.min c n)


accumulate : RawLap -> ( Bests, List Lap ) -> ( Bests, List Lap )
accumulate raw ( bests, acc ) =
    let
        lapTime =
            Lap.recorded raw.lapTime

        newBests =
            { lap = minMaybe bests.lap lapTime
            , sectors = Sector.map2 minMaybe bests.sectors raw.sectors
            , miniSectors =
                -- The feed records mini-sectors on a lap it has no lap time
                -- for, which is not a lap of the circuit.
                -- `BestTimes.miniSectorTime` and the CLI that measures the
                -- track both throw those out, and a baseline that kept them
                -- would rate a time against a record no one holds.
                case ( lapTime, raw.miniSectors ) of
                    ( Just _, Just miniSectors ) ->
                        LeMans.map2 (\best mini -> minMaybe best mini.time) bests.miniSectors miniSectors

                    _ ->
                        bests.miniSectors
            }

        lap =
            { carNumber = raw.carNumber
            , driver = Driver.fromName raw.driverName
            , lap = raw.lapNumber
            , position = Just raw.position

            -- The zero stops here: the CLI writes an unrecorded lap time out as
            -- `0.000` either way, where a blank sector cell stays blank and has
            -- already arrived as `Nothing`.
            , time = lapTime
            , best = newBests.lap
            , sectors =
                Sector.map2
                    (\time personalBest -> { time = time, personalBest = personalBest })
                    raw.sectors
                    newBests.sectors
            , elapsed = raw.elapsed
            , pitTime = raw.pitTime
            , miniSectors =
                raw.miniSectors
                    |> Maybe.map
                        (\miniSectors ->
                            LeMans.map2
                                (\mini personalBest ->
                                    { time = mini.time
                                    , elapsedInLap = mini.elapsedInLap
                                    , personalBest = personalBest
                                    }
                                )
                                miniSectors
                                newBests.miniSectors
                        )
            }
    in
    ( newBests, lap :: acc )
