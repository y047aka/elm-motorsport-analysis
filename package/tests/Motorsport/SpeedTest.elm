module Motorsport.SpeedTest exposing (suite)

import Expect
import Motorsport.Speed as Speed exposing (Speed)
import Test exposing (Test, describe, test)


{-| The reason the type exists at all: a reading of the field subtracts one speed
from another and keeps the result, so the subtraction has to come back exact and the
printing has to round rather than drift.
-}
suite : Test
suite =
    describe "Motorsport.Speed"
        [ describe "ofKmh and toTenths"
            [ test "the tenth the feed writes a speed at round-trips" <|
                \_ ->
                    Speed.ofKmh 328.8
                        |> Speed.toTenths
                        |> Expect.equal 3288
            , test "a speed between the tenths rounds to one, both ways" <|
                \_ ->
                    ( Speed.ofKmh 88.54 |> Speed.toTenths
                    , Speed.ofKmh 88.56 |> Speed.toTenths
                    )
                        |> Expect.equal ( 885, 886 )
            , test "and a mean of the tenths a car ran comes back in kilometres" <|
                \_ ->
                    Speed.toKmh (Speed.ofTenths 3288)
                        |> Expect.within (Expect.Absolute 0.0001) 328.8
            ]
        , describe "difference"
            [ test "stands signed, whichever way it falls" <|
                \_ ->
                    ( Speed.difference (Speed.ofTenths 3312) (Speed.ofTenths 3288)
                    , Speed.difference (Speed.ofTenths 3288) (Speed.ofTenths 3312)
                    )
                        |> Expect.equal ( Speed.ofTenths 24, Speed.ofTenths -24 )
            , test "of a mean over the laps a class ran is exact, which is the whole reason a speed is an integer" <|
                \_ ->
                    -- The subtraction a deployment is: a car's own trap speed
                    -- against its class. Through Floats this is where a reading
                    -- would come back 3.9999999999999437 and need a tolerance to
                    -- be compared with the next car's.
                    List.map Speed.ofKmh [ 301.1, 302.7, 303.3, 299.9 ]
                        |> List.map (Speed.difference (Speed.ofKmh 304.0) >> Speed.toTenths)
                        |> List.sum
                        |> Expect.equal 90
            ]
        , describe "toString"
            [ test "writes the magnitude and the tenth it carries" <|
                \_ ->
                    ( Speed.toString (Speed.ofTenths 3288)
                    , Speed.toString (Speed.ofTenths -18)
                    , Speed.toString Speed.zero
                    )
                        |> Expect.equal ( "328.8", "-1.8", "0.0" )
            , test "and toSignedString writes the way it fell" <|
                \_ ->
                    ( Speed.toSignedString (Speed.ofTenths 24)
                    , Speed.toSignedString (Speed.ofTenths -18)
                    , Speed.toSignedString Speed.zero
                    )
                        |> Expect.equal ( "+2.4", "-1.8", "0.0" )
            ]
        , describe "magnitude"
            [ test "is how far from nothing, whichever way it fell" <|
                \_ ->
                    Speed.magnitude (Speed.ofTenths -18)
                        |> Speed.toTenths
                        |> Expect.equal 18
            ]
        ]
