module Motorsport.DurationTest exposing (tests)

import Expect
import Fuzz
import Motorsport.Duration as Duration
import Test exposing (..)


{-| Fuzz test: Duration.toString >> Duration.fromString should be identity for valid Durations.
-}
tests : Test
tests =
    describe "Duration round-trip"
        [ fuzz (Fuzz.intRange -99999999 99999999) "Fuzz test" <|
            \duration ->
                let
                    durationString =
                        Duration.toString duration

                    result =
                        Duration.fromString durationString |> Maybe.map Duration.toString
                in
                Expect.equal (Just durationString) result
        , test "1001 should round-trip correctly" <|
            \_ ->
                let
                    result =
                        Duration.fromString "1.001" |> Maybe.map Duration.toString
                in
                Expect.equal (Just "1.001") result
        , test "an exact half-millisecond rounds up" <|
            -- 0.5005 s is exactly 500.5 ms, but the nearest Double to it is
            -- 500.49999999999994, so reading the seconds through a Float and
            -- rounding back out of it answered 500. Reading the digits as
            -- integers answers what they say.
            \_ ->
                Duration.fromString "0.5005"
                    |> Expect.equal (Just 501)
        , test "a part that is not a run of digits is not a duration" <|
            \_ ->
                [ "1:ab.000", "1:-30.000", "--4.321", "1e3", "" ]
                    |> List.map Duration.fromString
                    |> Expect.equal (List.repeat 5 Nothing)
        ]
