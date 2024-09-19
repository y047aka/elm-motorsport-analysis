module Motorsport.Duration exposing (Duration, durationDecoder, fromString, toString)

import Json.Decode as Decode exposing (Decoder)


type alias Duration =
    Int



-- DECODER


durationDecoder : Decoder Duration
durationDecoder =
    Decode.int


{-|

    toString 0
    --> "0.000"

    toString 4321
    --> "4.321"

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


{-|

    fromString "0.000"
    --> Just 0

    fromString "4.321"
    --> Just 4321

    fromString "06:54.321"
    --> Just 414321

    fromString "7:06:54.321"
    --> Just 25614321

-}
fromString : String -> Maybe Duration
fromString str =
    let
        fromHours h =
            String.toInt h |> Maybe.map ((*) 3600000)

        fromMinutes m =
            String.toInt m |> Maybe.map ((*) 60000)

        fromSeconds s =
            String.toFloat s |> Maybe.map ((*) 1000 >> floor)
    in
    case String.split ":" str of
        [ h, m, s ] ->
            Maybe.map3 (\h_ m_ s_ -> h_ + m_ + s_)
                (fromHours h)
                (fromMinutes m)
                (fromSeconds s)

        [ m, s ] ->
            Maybe.map2 (+)
                (fromMinutes m)
                (fromSeconds s)

        [ s ] ->
            fromSeconds s

        _ ->
            Nothing
