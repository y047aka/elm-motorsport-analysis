module Data.Wec.CarImage exposing (CarImages, none, decoder, url)

{-| Where a car's photograph is, season by season and round by round.

The table is `/static/car-images.json`, which `nix run .#car-images` writes and
no compiler reads, so a mistake in it shows as a car drawn without a photograph
rather than as a build that fails.

@docs CarImages, none, decoder, url

-}

import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder, field, string)
import Json.Decode.Pipeline exposing (required)


type alias CarImages =
    Dict String Season


type alias Season =
    { basePath : String
    , cars : Dict String Liveries
    }


{-| `rounds` is keyed as the calendar keys a round -- `le_mans_24h` -- and a key
spelt any other way is never reached rather than refused.
-}
type alias Liveries =
    { default : String
    , rounds : Dict String String
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
        |> required "cars" (Decode.dict liveriesDecoder)


{-| A car is a file name, or the file its rounds use by default beside the
rounds photographed apart from it.

`rounds` is `required` of that second form rather than `optional`: misspelt, an
optional key would read as a car with no livery of its own and put the default
on every round -- a wrong picture rather than a missing one.

-}
liveriesDecoder : Decoder Liveries
liveriesDecoder =
    Decode.oneOf
        [ Decode.map (\file -> Liveries file Dict.empty) string
        , Decode.succeed Liveries
            |> required "default" string
            |> required "rounds" (Decode.dict string)
        ]


url : CarImages -> { season : Int, round : String, carNumber : String } -> Maybe String
url carImages { season, round, carNumber } =
    let
        fileFor liveries =
            Dict.get round liveries.rounds
                |> Maybe.withDefault liveries.default
    in
    Dict.get (String.fromInt season) carImages
        |> Maybe.andThen
            (\seasonImages ->
                Dict.get carNumber seasonImages.cars
                    |> Maybe.map
                        (\liveries -> seasonImages.basePath ++ "/" ++ fileFor liveries)
            )
