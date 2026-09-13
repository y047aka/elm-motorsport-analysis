module Data.Wec.CarImage exposing (CarImages, none, decoder, url)

{-| Where a car's photograph is, season by season.

The table is `/static/car-images.json`, which is written by hand and which no
compiler reads, so a mistake in it shows as a car drawn without a photograph
rather than as a build that fails.

A season holds one image per car and a livery is not held that way: some are
carried for a single round. 2025's car 7 is photographed here in the livery it
ran at Le Mans and nowhere else, and `2_7967b9.png` -- the livery of its other
rounds -- sits in `static/images/wec/2025` with nothing naming it.

@docs CarImages, none, decoder, url

-}

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, field, string)
import Json.Decode.Pipeline exposing (required)


type alias CarImages =
    Dict String Season


type alias Season =
    { basePath : String
    , cars : Dict String String
    }


none : CarImages
none =
    Dict.empty


decoder : Decoder CarImages
decoder =
    field "seasons" (Decode.dict seasonDecoder)


seasonDecoder : Decoder Season
seasonDecoder =
    Decode.succeed Season
        |> required "basePath" string
        |> required "cars" (Decode.dict string)


url : CarImages -> { season : Int, carNumber : String } -> Maybe String
url carImages { season, carNumber } =
    Dict.get (String.fromInt season) carImages
        |> Maybe.andThen
            (\seasonImages ->
                Dict.get carNumber seasonImages.cars
                    |> Maybe.map (\file -> seasonImages.basePath ++ "/" ++ file)
            )
