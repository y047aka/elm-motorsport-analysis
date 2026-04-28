module Data.Wec.Laps exposing
    ( RawLap
    , decoder
    , attach
    )

{-|

@docs RawLap
@docs decoder
@docs attach

-}

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, int, string)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (required)
import List.Extra
import Motorsport.Car exposing (Car, CarNumber)
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Lap exposing (Lap)


type alias RawLap =
    { carNumber : String
    , driverName : String
    , lapNumber : Int
    , lapTime : Duration
    , s1 : Maybe Duration
    , s2 : Maybe Duration
    , s3 : Maybe Duration
    , elapsed : Duration
    , pitTime : Maybe Duration
    }



-- DECODE


decoder : Decoder (List RawLap)
decoder =
    Decode.list rawLapDecoder


rawLapDecoder : Decoder RawLap
rawLapDecoder =
    Decode.succeed RawLap
        |> required "carNumber" string
        |> required "driverName" string
        |> required "lapNumber" int
        |> required "lapTime" durationDecoder
        |> required "s1" optionalDurationDecoder
        |> required "s2" optionalDurationDecoder
        |> required "s3" optionalDurationDecoder
        |> required "elapsed" durationDecoder
        |> required "pitTime" optionalDurationDecoder


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

Mirrors the Rust CLI's `process_laps` + `position_for_lap`
(`cli/cli/src/stages/transform.rs`).

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
    , s1 : Maybe Duration
    , s2 : Maybe Duration
    , s3 : Maybe Duration
    }


bestsInit : Bests
bestsInit =
    { lap = Nothing, s1 = Nothing, s2 = Nothing, s3 = Nothing }


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
        newBests =
            { lap = minMaybe bests.lap (Just raw.lapTime)
            , s1 = minMaybe bests.s1 raw.s1
            , s2 = minMaybe bests.s2 raw.s2
            , s3 = minMaybe bests.s3 raw.s3
            }

        lap =
            { carNumber = raw.carNumber
            , driver = Driver raw.driverName
            , lap = raw.lapNumber
            , position = Nothing
            , time = raw.lapTime
            , best = newBests.lap |> Maybe.withDefault 0
            , sector_1 = raw.s1 |> Maybe.withDefault 0
            , sector_2 = raw.s2 |> Maybe.withDefault 0
            , sector_3 = raw.s3 |> Maybe.withDefault 0
            , s1_best = newBests.s1 |> Maybe.withDefault 0
            , s2_best = newBests.s2 |> Maybe.withDefault 0
            , s3_best = newBests.s3 |> Maybe.withDefault 0
            , elapsed = raw.elapsed
            , pitTime = raw.pitTime
            , miniSectors = Nothing
            }
    in
    ( newBests, lap :: acc )



-- POSITIONS


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
                            |> Maybe.map (\lap -> ( idx, lap.elapsed ))
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
