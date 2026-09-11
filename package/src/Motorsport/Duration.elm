module Motorsport.Duration exposing
    ( Duration
    , decoder
    , toString
    , toStringToSeconds, toStringToTenths
    , fromString, fromStringWithDefault
    )

{-|

@docs Duration
@docs decoder
@docs toString
@docs toStringToSeconds, toStringToTenths
@docs fromString, fromStringWithDefault

-}

import Json.Decode as Decode exposing (Decoder)


type alias Duration =
    Int



-- DECODER


decoder : Decoder Duration
decoder =
    Decode.string
        |> Decode.andThen
            (\str ->
                case fromString str of
                    Just duration ->
                        Decode.succeed duration

                    Nothing ->
                        Decode.fail ("Expected a Duration, got \"" ++ str ++ "\"")
            )


{-|

    toString 0
    --> "0.000"

    toString 4321
    --> "4.321"

    toString 28076
    --> "28.076"

    toString 414321
    --> "6:54.321"

    toString 25614321
    --> "7:06:54.321"

A duration can come out negative — a moment measured against a later one — and
carries a single leading sign rather than one per part:

    toString (-4321)
    --> "-4.321"

-}
toString : Duration -> String
toString ms =
    if ms < 0 then
        "-" ++ toString (abs ms)

    else if ms < (60 * 1000) then
        toStringInSeconds ms

    else if ms < (60 * 60 * 1000) then
        toStringInMinutes ms

    else
        toStringInHours ms


{-| The same spelling as [`toString`](#toString), stopped at whole seconds.

    toStringToSeconds 4321
    --> "4"

    toStringToSeconds 65432
    --> "1:05"

    toStringToSeconds 25614321
    --> "7:06:54"

-}
toStringToSeconds : Duration -> String
toStringToSeconds ms =
    if ms < 0 then
        "-" ++ toStringToSeconds (abs ms)

    else
        let
            seconds =
                ms // 1000

            h =
                seconds // 3600 |> String.fromInt

            m =
                remainderBy 3600 seconds
                    // 60
                    |> String.fromInt
                    |> String.padLeft 2 '0'

            s =
                remainderBy 60 seconds
                    |> String.fromInt
                    |> String.padLeft 2 '0'
        in
        if seconds < 60 then
            String.fromInt seconds

        else if seconds < 3600 then
            String.join ":" [ String.fromInt (seconds // 60), s ]

        else
            String.join ":" [ h, m, s ]


{-| The same spelling as [`toStringToSeconds`](#toStringToSeconds), carried one
place further. Truncated like it is, so a clock being counted up never shows a
tenth it has yet to reach.

    toStringToTenths 4321
    --> "4.3"

    toStringToTenths 65432
    --> "1:05.4"

    toStringToTenths 25614321
    --> "7:06:54.3"

    toStringToTenths (-4321)
    --> "-4.3"

-}
toStringToTenths : Duration -> String
toStringToTenths ms =
    if ms < 0 then
        "-" ++ toStringToTenths (abs ms)

    else
        let
            tenths =
                remainderBy 1000 ms // 100 |> String.fromInt
        in
        toStringToSeconds ms ++ "." ++ tenths


toStringInSeconds : Duration -> String
toStringInSeconds milliseconds =
    let
        s =
            (milliseconds // 1000)
                |> String.fromInt

        ms =
            remainderBy 1000 milliseconds
                |> String.fromInt
                |> String.padLeft 3 '0'
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
                |> String.padLeft 3 '0'
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
                |> String.padLeft 3 '0'
    in
    String.join ":" [ h, m, s ++ "." ++ ms ]


{-| Read a duration back off the wire, spelled the way [`toString`](#toString)
writes it. Times arrive with three decimal places, so the fractional part is
already a count of milliseconds.

    fromString "0.000"
    --> Just 0

    fromString "4.321"
    --> Just 4321

    fromString "06:54.321"
    --> Just 414321

    fromString "7:06:54.321"
    --> Just 25614321

    fromString "-6:54.321"
    --> Just -414321

-}
fromString : String -> Maybe Duration
fromString str =
    case String.uncons str of
        Just ( '-', rest ) ->
            fromString rest |> Maybe.map negate

        _ ->
            fromPositiveString str


fromPositiveString : String -> Maybe Duration
fromPositiveString str =
    let
        fromHours h =
            String.toInt h |> Maybe.map ((*) 3600000)

        fromMinutes m =
            String.toInt m |> Maybe.map ((*) 60000)

        -- Read as digits rather than through `String.toFloat`, which cannot
        -- hold a millisecond exactly and had to be rounded back out of.
        -- A shorter fraction is padded out; a longer one is not read.
        fromSeconds s =
            case String.split "." s of
                [ whole, fraction ] ->
                    Maybe.map2 (\whole_ ms -> (whole_ * 1000) + ms)
                        (String.toInt whole)
                        (fraction |> String.padRight 3 '0' |> String.left 3 |> String.toInt)

                [ whole ] ->
                    String.toInt whole |> Maybe.map ((*) 1000)

                _ ->
                    Nothing
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


fromStringWithDefault : Duration -> String -> Duration
fromStringWithDefault default =
    fromString >> Maybe.withDefault default
