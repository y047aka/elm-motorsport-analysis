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
        [ fuzz (Fuzz.intRange 0 99999999) "Fuzz test" <|
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
        ]
