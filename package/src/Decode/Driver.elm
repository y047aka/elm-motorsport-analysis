module Decode.Driver exposing (decoder)

{-| Reading a [`Driver`](Motorsport-Driver) out of a feed.

@docs decoder

-}

import Json.Decode as Decode exposing (Decoder)
import Motorsport.Driver as Driver exposing (Driver)
import PersonName.Parse exposing (fromUppercasedSurname)


{-| The driver a feed names, out of the string it names them by: `Kamui KOBAYASHI`.

    import Json.Decode exposing (Error, decodeString)
    import Motorsport.Driver as Driver

    shown : String -> Result Error String
    shown =
        decodeString decoder >> Result.map Driver.initialsAndSurname

    shown "\"Kamui KOBAYASHI\""
    --> Ok "K.KOBAYASHI"

    shown "\"Kelvin VAN DER LINDE\""
    --> Ok "K.VAN DER LINDE"

-}
decoder : Decoder Driver
decoder =
    Decode.string
        |> Decode.andThen
            (\name ->
                case fromUppercasedSurname name of
                    Just person ->
                        Decode.succeed (Driver.fromName person)

                    Nothing ->
                        Decode.fail ("a driver named nothing: " ++ name)
            )
