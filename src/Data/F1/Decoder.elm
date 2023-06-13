module Data.F1.Decoder exposing (Car, Driver, Lap, carDecoder, carsDecoder, preprocess)

import Data.Duration exposing (Duration, durationDecoder)
import Data.Lap as Lap
import Json.Decode as Decode exposing (Decoder, field, int, string)



-- TYPE


type alias Car =
    { carNumber : String
    , driver : Driver
    , laps : List Lap
    }


type alias Driver =
    { name : String }


type alias Lap =
    { lap : Int, time : Duration }



-- DECODER


carsDecoder : Decoder (List Car)
carsDecoder =
    Decode.list carDecoder


carDecoder : Decoder Car
carDecoder =
    Decode.map3 Car
        (field "carNumber" string)
        (field "driver" driverDecoder)
        (field "laps" <| Decode.list lapDecoder)


driverDecoder : Decoder Driver
driverDecoder =
    Decode.map Driver
        (field "name" string)


lapDecoder : Decoder Lap
lapDecoder =
    Decode.map2 (\lap time -> { lap = lap, time = time })
        (field "lap" int)
        (field "time" durationDecoder)



-- PREPROCESSOR


preprocess : List Car -> List (List Lap.Lap)
preprocess =
    List.map preprocess_


preprocess_ : Car -> List Lap.Lap
preprocess_ { carNumber, driver, laps } =
    List.indexedMap
        (\count { lap, time } ->
            { carNumber = carNumber
            , driver = driver.name
            , lap = lap
            , time = time
            , best =
                laps
                    |> List.take (count + 1)
                    |> List.map .time
                    |> List.minimum
                    |> Maybe.withDefault 0
            , elapsed =
                laps
                    |> List.take (count + 1)
                    |> List.foldl (.time >> (+)) 0
            }
        )
        laps
