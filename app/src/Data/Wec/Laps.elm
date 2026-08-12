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
import List.Extra
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Sector as Sector exposing (BySector)
import Motorsport.Wec.Circuit.LeMans as LeMans exposing (ByMiniSector)


type alias RawLap =
    { carNumber : String
    , driverName : String
    , lapNumber : Int
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
fromJsonl body =
    body
        |> String.lines
        |> List.indexedMap Tuple.pair
        |> List.foldr decodeLine (Ok [])


decodeLine : ( Int, String ) -> Result String (List RawLap) -> Result String (List RawLap)
decodeLine ( index, line ) rest =
    if String.isEmpty line then
        rest

    else
        case Decode.decodeString rawLapDecoder line of
            Ok rawLap ->
                Result.map ((::) rawLap) rest

            Err error ->
                Err ("line " ++ String.fromInt (index + 1) ++ ": " ++ Decode.errorToString error)


rawLapDecoder : Decoder RawLap
rawLapDecoder =
    Decode.succeed RawLap
        |> required "carNumber" string
        |> required "driverName" string
        |> required "lapNumber" int
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
far. Every key is `optional`, unlike the same names in the summary's shares: the
CLI drops a mini-sector it has neither a time nor a running total for, so a key
short of fifteen is a mini-sector the feed says nothing about rather than a file
of the wrong shape, and the lap has to decode all the same.
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
best lap / sector times. Then assigns 0-based per-lap positions across all
cars by sorting `elapsed` ascending for each lap number.

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
        |> assignPositions


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
            , position = Nothing

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



-- POSITIONS
-- `Lap.position` is not in the source data; it is worked out here. Two things
-- downstream depend on it having been: the position-progression chart, and the
-- lead changes in `Motorsport.Race.TimelineEvent`. Both go quiet rather than
-- fail if it is skipped.


assignPositions : List Car -> List Car
assignPositions cars =
    let
        maxLap =
            cars
                |> List.concatMap .laps
                |> List.map .lap
                |> List.maximum
                |> Maybe.withDefault 0
    in
    List.foldl assignPositionsForLap cars (List.range 1 maxLap)


assignPositionsForLap : Int -> List Car -> List Car
assignPositionsForLap lapNum cars =
    let
        positionByIdx : Dict Int Int
        positionByIdx =
            cars
                |> List.indexedMap
                    (\idx car ->
                        List.Extra.find (\l -> l.lap == lapNum) car.laps
                            |> Maybe.map (\lap -> ( idx, Instant.toDuration lap.elapsed ))
                    )
                |> List.filterMap identity
                |> List.sortBy Tuple.second
                |> List.indexedMap (\pos ( idx, _ ) -> ( idx, pos ))
                |> Dict.fromList
    in
    cars
        |> List.indexedMap
            (\idx car ->
                case Dict.get idx positionByIdx of
                    Just position ->
                        { car
                            | laps =
                                car.laps
                                    |> List.map
                                        (\lap ->
                                            if lap.lap == lapNum then
                                                { lap | position = Just position }

                                            else
                                                lap
                                        )
                        }

                    Nothing ->
                        car
            )
