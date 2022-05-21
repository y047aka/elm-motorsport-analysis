module Data.Duration exposing (Duration, durationDecoder, toString)

import Json.Decode as Decode exposing (Decoder)


type alias Duration =
    Int



-- DECODER


durationDecoder : Decoder Duration
durationDecoder =
    Decode.int


{-|

    toString 0
    --> "0:00.000"

    toString 4321
    --> "0:04.321"

    toString 414321
    --> "6:54.321"

    toString 25614321
    --> "7:06:54.321"

-}
toString : Duration -> String
toString ms =
    if ms > (60 * 60 * 1000) then
        toStringInHours ms

    else if ms > (60 * 1000) then
        toStringInMinutes ms

    else
        toStringInSeconds ms


toStringInSeconds : Duration -> String
toStringInSeconds milliseconds =
    let
        s =
            (milliseconds // 1000)
                |> String.fromInt

        ms =
            remainderBy 1000 milliseconds
                |> String.fromInt
                |> String.padRight 3 '0'
    in
    s ++ "." ++ ms


toStringInMinutes : Duration -> String
toStringInMinutes milliseconds =
    let
        m =
            (milliseconds // (60 * 1000))
                |> String.fromInt

        s =
            (remainderBy (60 * 1000) milliseconds // 1000)
                |> String.fromInt
                |> String.padLeft 2 '0'

        ms =
            remainderBy 1000 milliseconds
                |> String.fromInt
                |> String.padRight 3 '0'
    in
    String.join ":" [ m, s ++ "." ++ ms ]


toStringInHours : Duration -> String
toStringInHours milliseconds =
    let
        h =
            (milliseconds // (60 * 60 * 1000))
                |> String.fromInt

        m =
            (remainderBy (60 * 60 * 1000) milliseconds // (60 * 1000))
                |> String.fromInt
                |> String.padLeft 2 '0'

        s =
            (remainderBy (60 * 1000) milliseconds // 1000)
                |> String.fromInt
                |> String.padLeft 2 '0'

        ms =
            remainderBy 1000 milliseconds
                |> String.fromInt
                |> String.padRight 3 '0'
    in
    String.join ":" [ h, m, s ++ "." ++ ms ]
