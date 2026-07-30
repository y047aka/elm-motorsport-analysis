module Fixture.Json exposing (decode, fixtureDecoder)

import Data.Wec.Laps as Laps
import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, list, string)
import Json.Decode.Extra
import Json.Decode.Pipeline exposing (required)
import Motorsport.Class as Class exposing (Class)
import Motorsport.Driver as Driver
import Motorsport.Entrant as Entrant exposing (Entrant)
import Motorsport.Manufacturer as Manufacturer exposing (Manufacturer)


decode : String -> List Entrant
decode raw =
    Decode.decodeString fixtureDecoder raw
        |> Result.withDefault []


fixtureDecoder : Decoder (List Entrant)
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


classDecoder : Decoder Class
classDecoder =
    string |> Decode.andThen (Class.fromString >> Json.Decode.Extra.fromMaybe "Expected a Class")


carsFromLapsDecoder : Decoder (List Entrant)
carsFromLapsDecoder =
    list lapCarInfoDecoder |> Decode.map extractCars


type alias CarData =
    { class : Class
    , group : String
    , team : String
    , manufacturer : Manufacturer
    , drivers : List String
    }


extractCars : List LapCarInfo -> List Entrant
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


toPlaceholderCar : ( String, CarData ) -> Entrant
toPlaceholderCar ( carNumber, data ) =
    Entrant.fromStartingGrid
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
