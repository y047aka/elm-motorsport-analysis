module Fixture.Json exposing (decode, fixtureDecoder)

import Data.Wec.Laps as Laps
import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, list, string)
import Json.Decode.Pipeline exposing (required)
import Motorsport.Wec.Class as Class exposing (Class)
import Motorsport.Wec.Era as Era
import Motorsport.Driver as Driver
import Motorsport.Wec.Manufacturer as Manufacturer exposing (Manufacturer)
import Motorsport.Race.Car as Car exposing (Car)


decode : String -> List Car
decode raw =
    Decode.decodeString fixtureDecoder raw
        |> Result.withDefault []


fixtureDecoder : Decoder (List Car)
fixtureDecoder =
    Decode.map2 Laps.attach
        Laps.decoder
        carsFromLapsDecoder


type alias LapCarInfo =
    { carNumber : String
    , driverName : String
    , class : Class
    , group : String
    , team : String
    , manufacturer : Manufacturer
    }


lapCarInfoDecoder : Decoder LapCarInfo
lapCarInfoDecoder =
    Decode.succeed LapCarInfo
        |> required "carNumber" string
        |> required "driverName" string
        |> required "class" classDecoder
        |> required "group" string
        |> required "team" string
        |> required "manufacturer" (string |> Decode.map Manufacturer.fromString)


{-| The fixture is the 2025 Fuji 6 Hours; see `benchmark/generate-fixture.mjs`.
-}
classDecoder : Decoder Class
classDecoder =
    string |> Decode.map (Class.fromString Era.Gt3AsThirdClass)


carsFromLapsDecoder : Decoder (List Car)
carsFromLapsDecoder =
    list lapCarInfoDecoder |> Decode.map extractCars


type alias CarData =
    { class : Class
    , group : String
    , team : String
    , manufacturer : Manufacturer
    , drivers : List String
    }


extractCars : List LapCarInfo -> List Car
extractCars infos =
    infos
        |> List.foldr collectCarData Dict.empty
        |> Dict.toList
        |> List.map toPlaceholderCar


collectCarData : LapCarInfo -> Dict String CarData -> Dict String CarData
collectCarData info acc =
    case Dict.get info.carNumber acc of
        Just existing ->
            Dict.insert info.carNumber
                { existing
                    | drivers =
                        if List.member info.driverName existing.drivers then
                            existing.drivers

                        else
                            existing.drivers ++ [ info.driverName ]
                }
                acc

        Nothing ->
            Dict.insert info.carNumber
                { class = info.class
                , group = info.group
                , team = info.team
                , manufacturer = info.manufacturer
                , drivers = [ info.driverName ]
                }
                acc


toPlaceholderCar : ( String, CarData ) -> Car
toPlaceholderCar ( carNumber, data ) =
    Car.fromStartingGrid
        { position = 0
        , car =
            { carNumber = carNumber
            , drivers = List.map Driver.fromName data.drivers
            , class = data.class
            , group = data.group
            , team = data.team
            , manufacturer = data.manufacturer
            }
        }
