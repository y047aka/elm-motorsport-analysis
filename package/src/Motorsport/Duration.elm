module Motorsport.Duration exposing
    ( Duration
    , durationDecoder
    , toString
    , fromString, fromStringWithDefault
    )

{-|

@docs Duration
@docs durationDecoder
@docs toString
@docs fromString, fromStringWithDefault

-}

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


{-| Read a duration back off the wire, spelled the way
[`toString`](#toString) writes it: `[[H:]MM:]SS[.fff]`, with an optional
leading sign.

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

Every part is a whole number of its own unit, so a field that is not a run of
digits is not a duration:

    fromString "1:ab.000"
    --> Nothing

The sign belongs to the duration rather than to any one part of it, and there
is only ever one:

    fromString "1:-30.000"
    --> Nothing

    fromString "--4.321"
    --> Nothing

Past three decimal places there is more precision on offer than a duration
holds, and it rounds to the nearest millisecond:

    fromString "1.2345"
    --> Just 1235

-}
fromString : String -> Maybe Duration
fromString str =
    case String.uncons str of
        Just ( '-', rest ) ->
            fromPositiveString rest |> Maybe.map negate

        _ ->
            fromPositiveString str


fromPositiveString : String -> Maybe Duration
fromPositiveString str =
    case String.split ":" str of
        [ h, m, s ] ->
            Maybe.map3 (\h_ m_ s_ -> (h_ * 60 * 60 * 1000) + (m_ * 60 * 1000) + s_)
                (digits h)
                (digits m)
                (fromSeconds s)

        [ m, s ] ->
            Maybe.map2 (\m_ s_ -> (m_ * 60 * 1000) + s_)
                (digits m)
                (fromSeconds s)

        [ s ] ->
            fromSeconds s

        _ ->
            Nothing


{-| The seconds field, whole and fractional parts each read as an integer.

This used to go through `String.toFloat` and `round` back out of it. A
millisecond is not exactly representable as a binary fraction of a second, so
the reading was never the digits that were written -- only near enough to them
that rounding recovered the number.

-}
fromSeconds : String -> Maybe Duration
fromSeconds str =
    case String.split "." str of
        [ whole ] ->
            digits whole |> Maybe.map ((*) 1000)

        [ whole, fraction ] ->
            Maybe.map2 (\s ms -> (s * 1000) + ms)
                (digits whole)
                (milliseconds fraction)

        _ ->
            Nothing


{-| The fractional part of a seconds field, as whole milliseconds.

Read to four places and rounded to three, half away from zero -- which is where
reading the whole seconds field as a `Float` could not be trusted to land, since
a value like `.5005` is a hair under the half-millisecond once it is a `Double`
and rounded the wrong way.

A fraction that rounds up to a full second carries: `.9999` is 1000
milliseconds, and the caller adds it to the whole seconds either way.

-}
milliseconds : String -> Maybe Duration
milliseconds fraction =
    if String.all Char.isDigit fraction then
        String.padRight 4 '0' fraction
            |> String.left 4
            |> String.toInt
            |> Maybe.map (\tenthsOfAMilli -> (tenthsOfAMilli + 5) // 10)

    else
        Nothing


{-| A run of digits and nothing else. `String.toInt` would take a sign as well,
and a sign in the middle of a duration is not something to be lenient about.
-}
digits : String -> Maybe Int
digits str =
    if String.isEmpty str || not (String.all Char.isDigit str) then
        Nothing

    else
        String.toInt str


fromStringWithDefault : Duration -> String -> Duration
fromStringWithDefault default =
    fromString >> Maybe.withDefault default
