module Legacy.WecLaps exposing (RawLap, assignPositions, attach, fromJsonl)

{-| `Data.Wec.Laps` as it stood before the round's laps carried a position.
`PositionBenchmark` is the only reader.

The decoder here has no `position` field and `attach` leaves every lap's
`Nothing`, which `assignPositions` then fills -- the work that is now a window
function over `laps`.

-}

import Decode.Driver as Driver
import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, int, string)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (optional, required)
import List.Extra
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.MiniSector as MiniSector exposing (Named)
import Motorsport.Race.Car exposing (Car, CarNumber)
import Motorsport.Sector as Sector exposing (BySector)


type alias RawLap =
    { carNumber : String
    , driver : Driver
    , lapNumber : Int
    , lapTime : Duration
    , sectors : BySector (Maybe Duration)
    , miniSectors : Maybe (Dict String RawMiniSector)
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
        |> required "driverName" Driver.decoder
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
far, keyed by the name the file spells the mini-sector with. A key the CLI
leaves out is a mini-sector the feed says nothing about rather than a file of
the wrong shape.
-}
miniSectorsDecoder : Decoder (Dict String RawMiniSector)
miniSectorsDecoder =
    Decode.dict miniSectorDecoder


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
attach : List String -> List RawLap -> List Car -> List Car
attach miniSectorNames rawLaps cars =
    let
        lapsByCarNumber : Dict CarNumber (List Lap)
        lapsByCarNumber =
            rawLaps
                |> groupBy .carNumber
                |> Dict.map (\_ raws -> finalizeCarLaps miniSectorNames raws)
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


finalizeCarLaps : List String -> List RawLap -> List Lap
finalizeCarLaps miniSectorNames raws =
    raws
        |> List.sortBy .lapNumber
        |> List.foldl (accumulate miniSectorNames) ( bestsInit miniSectorNames, [] )
        |> Tuple.second
        |> List.reverse


type alias Bests =
    { lap : Maybe Duration
    , sectors : BySector (Maybe Duration)
    , miniSectors : Named (Maybe Duration)
    }


bestsInit : List String -> Bests
bestsInit miniSectorNames =
    { lap = Nothing
    , sectors = Sector.initialize (always Nothing)
    , miniSectors = List.map (\name -> { name = name, value = Nothing }) miniSectorNames
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


accumulate : List String -> RawLap -> ( Bests, List Lap ) -> ( Bests, List Lap )
accumulate miniSectorNames raw ( bests, acc ) =
    let
        lapTime =
            Lap.recorded raw.lapTime

        miniSectors =
            Maybe.map (byTrackOrder miniSectorNames) raw.miniSectors

        newBests =
            { lap = minMaybe bests.lap lapTime
            , sectors = Sector.map2 minMaybe bests.sectors raw.sectors
            , miniSectors =
                -- The feed records mini-sectors on a lap it has no lap time
                -- for, which is not a lap of the circuit. `Round.Index` throws
                -- those out of the records, and a baseline that kept them
                -- would rate a time against a record no one holds.
                case ( lapTime, miniSectors ) of
                    ( Just _, Just ms ) ->
                        MiniSector.map2 (\best mini -> minMaybe best mini.time) bests.miniSectors ms

                    _ ->
                        bests.miniSectors
            }

        lap =
            { carNumber = raw.carNumber
            , driver = raw.driver
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
            , crossing =
                -- The decoder this was frozen from never read the lap that
                -- ended in the pit lane, so an in lap reads here as a lap the
                -- car drove.
                raw.pitTime |> Maybe.map Lap.ExitAtStart |> Maybe.withDefault Lap.NoCrossing
            , miniSectors =
                miniSectors
                    |> Maybe.map
                        (\ms ->
                            MiniSector.map2
                                (\mini personalBest ->
                                    { time = mini.time
                                    , elapsedInLap = mini.elapsedInLap
                                    , personalBest = personalBest
                                    }
                                )
                                ms
                                newBests.miniSectors
                        )
            }
    in
    ( newBests, lap :: acc )


{-| The lap's mini-sectors in track order, under the names the round's shares
spell them with.
-}
byTrackOrder : List String -> Dict String RawMiniSector -> Named RawMiniSector
byTrackOrder names byName =
    List.map
        (\name ->
            { name = name
            , value =
                Dict.get name byName
                    |> Maybe.withDefault { time = Nothing, elapsedInLap = Nothing }
            }
        )
        names



-- POSITIONS
-- `Lap.position` is not in the source data; it is worked out here.


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
