module Motorsport.Internal.ChangePointsTest exposing (suite)

import Expect
import Motorsport.Duration exposing (Duration)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Internal.ChangePoints as ChangePoints exposing (ChangePoints)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "ChangePoints"
        [ describe "valueAt"
            [ test "reads nothing back before the first change" <|
                \_ ->
                    ChangePoints.valueAt (instant 999) index
                        |> Expect.equal Nothing
            , test "an empty index has nothing at any time" <|
                \_ ->
                    ChangePoints.valueAt (instant 500000) ChangePoints.empty
                        |> Expect.equal Nothing
            , test "a change takes effect on the instant it happens, not the one after" <|
                \_ ->
                    Expect.equal
                        ( Just "a", Just "b" )
                        ( ChangePoints.valueAt (instant 2999) index
                        , ChangePoints.valueAt (instant 3000) index
                        )
            , test "holds the last value once the changes run out" <|
                \_ ->
                    ChangePoints.valueAt (instant 9999999) index
                        |> Expect.equal (Just "d")
            , test "the last of two changes sharing an instant wins" <|
                \_ ->
                    ChangePoints.fromList [ ( instant 500, "first" ), ( instant 500, "second" ) ]
                        |> ChangePoints.valueAt (instant 500)
                        |> Expect.equal (Just "second")
            , test "an unsorted list is indexed as if it had been sorted" <|
                \_ ->
                    ChangePoints.fromList [ ( instant 3000, "b" ), ( instant 1000, "a" ) ]
                        |> ChangePoints.valueAt (instant 2000)
                        |> Expect.equal (Just "a")
            ]
        , describe "last"
            [ test "gives the value in force once every change has happened" <|
                \_ ->
                    ChangePoints.last index
                        |> Expect.equal (ChangePoints.valueAt (instant 9999999) index)
            , test "an empty index has no last value" <|
                \_ ->
                    ChangePoints.last ChangePoints.empty
                        |> Expect.equal Nothing
            ]
        , describe "countUpTo"
            [ test "counts the changes at or before the clock" <|
                \_ ->
                    [ -1, 0, 1000, 2999, 3000, 6000, 6001, 9999999 ]
                        |> List.map (\elapsed -> ChangePoints.countUpTo (instant elapsed) index)
                        |> Expect.equal [ 0, 0, 1, 1, 2, 4, 4, 4 ]
            ]
        , describe "timeOfNth"
            [ test "gives the moment of the nth change, and nothing past the end" <|
                \_ ->
                    [ ChangePoints.timeOfNth 0 index
                    , ChangePoints.timeOfNth 3 index
                    , ChangePoints.timeOfNth 4 index
                    ]
                        |> Expect.equal [ Just (instant 1000), Just (instant 6000), Nothing ]
            ]
        , describe "length"
            [ test "counts every change" <|
                \_ ->
                    ChangePoints.length index
                        |> Expect.equal 4
            ]
        , describe "the binary search"
            -- Two hundred changes sampled every half-interval, so every boundary
            -- is hit from both sides.
            [ test "reads the same values a linear scan would" <|
                \_ ->
                    samples
                        |> List.map (\elapsed -> ChangePoints.valueAt (instant elapsed) longIndex)
                        |> Expect.equal (List.map scanValue samples)
            , test "counts the same changes a linear scan would" <|
                \_ ->
                    samples
                        |> List.map (\elapsed -> ChangePoints.countUpTo (instant elapsed) longIndex)
                        |> Expect.equal (List.map scanCount samples)
            ]
        ]



-- FIXTURE


{-| The fixtures below are written in plain milliseconds and lifted to
[`Instant`](Motorsport-Instant) here, so the numbers stay readable.
-}
instant : Duration -> Instant
instant =
    Instant.fromDuration


index : ChangePoints String
index =
    ChangePoints.fromList
        [ ( instant 1000, "a" )
        , ( instant 3000, "b" )
        , ( instant 5000, "c" )
        , ( instant 6000, "d" )
        ]


longChanges : List ( Duration, Int )
longChanges =
    List.range 1 200 |> List.map (\i -> ( i * 1000, i ))


longIndex : ChangePoints Int
longIndex =
    ChangePoints.fromList (List.map (Tuple.mapFirst instant) longChanges)


samples : List Duration
samples =
    List.range 0 402 |> List.map (\i -> i * 500)



-- THE SPECIFICATION THE SEARCH IMPLEMENTS


upTo : Duration -> List ( Duration, Int )
upTo elapsed =
    List.filter (\( time, _ ) -> time <= elapsed) longChanges


scanValue : Duration -> Maybe Int
scanValue elapsed =
    upTo elapsed
        |> List.reverse
        |> List.head
        |> Maybe.map Tuple.second


scanCount : Duration -> Int
scanCount elapsed =
    List.length (upTo elapsed)
