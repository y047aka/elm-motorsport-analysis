module Data.LapTime exposing (LapTime, fromString, lapTimeDecoder, toString)

import Json.Decode as Decode exposing (Decoder)


type alias LapTime =
    Int



-- DECODER


lapTimeDecoder : Decoder LapTime
lapTimeDecoder =
    Decode.int


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
fromString : String -> Maybe LapTime
fromString str =
    let
        h_fromString h =
            String.toInt h |> Maybe.map ((*) 3600000)

        m_fromString m =
            String.toInt m |> Maybe.map ((*) 60000)

        s_fromString s =
            String.toFloat s |> Maybe.map ((*) 1000 >> floor)
    in
    case String.split ":" str of
        [ h, m, s ] ->
            Maybe.map3 (\h_ m_ s_ -> h_ + m_ + s_)
                (h_fromString h)
                (m_fromString m)
                (s_fromString s)

        [ m, s ] ->
            Maybe.map2 (+)
                (m_fromString m)
                (s_fromString s)

        [ s ] ->
            s_fromString s

        _ ->
            Nothing


{-|

    toString 0
    --> "00:00.000"

    toString 4321
    --> "00:04.321"

    toString 414321
    --> "06:54.321"

    toString 25614321
    --> "07:06:54.321"

-}
toString : LapTime -> String
toString millis =
    let
        h =
            (millis // 3600000)
                |> String.fromInt
                |> String.padLeft 2 '0'

        m =
            (remainderBy 3600000 millis // 60000)
                |> String.fromInt
                |> String.padLeft 2 '0'

        s =
            (remainderBy 60000 millis // 1000)
                |> String.fromInt
                |> String.padLeft 2 '0'

        ms =
            remainderBy 1000 millis
                |> String.fromInt
                |> String.padRight 3 '0'
                |> (++) "."
    in
    if millis >= 3600000 then
        String.join ":" [ h, m, s ++ ms ]

    else
        String.join ":" [ m, s ++ ms ]
