module Motorsport.Internal.Jsonl exposing (decode)

{-| The files the CLI writes one record per line.

@docs decode

-}

import Json.Decode as Decode exposing (Decoder)


{-| Every line of a JSON Lines body, or the first line that would not decode,
named by the number it is on.

A trailing newline leaves a blank line behind, which is skipped rather than
failed.

-}
decode : Decoder a -> String -> Result String (List a)
decode decoder body =
    body
        |> String.lines
        |> List.indexedMap Tuple.pair
        |> List.foldr (decodeLine decoder) (Ok [])


decodeLine : Decoder a -> ( Int, String ) -> Result String (List a) -> Result String (List a)
decodeLine decoder ( index, line ) rest =
    if String.isEmpty line then
        rest

    else
        case Decode.decodeString decoder line of
            Ok value ->
                Result.map ((::) value) rest

            Err error ->
                Err ("line " ++ String.fromInt (index + 1) ++ ": " ++ Decode.errorToString error)
