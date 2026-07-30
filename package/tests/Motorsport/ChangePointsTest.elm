module Motorsport.ChangePointsTest exposing (suite)

import Expect
import Motorsport.ChangePoints as ChangePoints exposing (ChangePoints)
import Motorsport.Duration exposing (Duration)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "ChangePoints"
        [ describe "valueAt"
            [ test "reads nothing back before the first change" <|
                \_ ->
                    ChangePoints.valueAt 999 index
                        |> Expect.equal Nothing
            , test "an empty index has nothing at any time" <|
                \_ ->
                    ChangePoints.valueAt 500000 emptyIndex
                        |> Expect.equal Nothing
            , test "a change takes effect on the instant it happens, not the one after" <|
                \_ ->
                    Expect.equal
                        ( Just "a", Just "b" )
                        ( ChangePoints.valueAt 2999 index
                        , ChangePoints.valueAt 3000 index
                        )
            , test "holds the last value once the changes run out" <|
                \_ ->
                    ChangePoints.valueAt 9999999 index
                        |> Expect.equal (Just "d")
            , test "the last of two changes sharing an instant wins" <|
                \_ ->
                    ChangePoints.fromList [ ( 500, "first" ), ( 500, "second" ) ]
                        |> ChangePoints.valueAt 500
                        |> Expect.equal (Just "second")
            , test "an unsorted list is indexed as if it had been sorted" <|
                \_ ->
                    ChangePoints.fromList [ ( 3000, "b" ), ( 1000, "a" ) ]
                        |> ChangePoints.valueAt 2000
                        |> Expect.equal (Just "a")
            ]
        , describe "last"
            [ test "gives the value in force once every change has happened" <|
                \_ ->
                    ChangePoints.last index
                        |> Expect.equal (Just "d")
            , test "agrees with reading past the final change" <|
                \_ ->
                    ChangePoints.last index
                        |> Expect.equal (ChangePoints.valueAt 9999999 index)
            , test "an empty index has no last value" <|
                \_ ->
                    ChangePoints.last emptyIndex
                        |> Expect.equal Nothing
            ]
        , describe "countUpTo"
            [ test "counts the changes at or before the clock" <|
                \_ ->
                    [ -1, 0, 1000, 2999, 3000, 6000, 6001, 9999999 ]
                        |> List.map (\elapsed -> ChangePoints.countUpTo elapsed index)
                        |> Expect.equal [ 0, 0, 1, 1, 2, 4, 4, 4 ]
            ]
        , describe "timeOf"
            [ test "gives the moment of the nth change, and nothing past the end" <|
                \_ ->
                    [ ChangePoints.timeOf 0 index
                    , ChangePoints.timeOf 3 index
                    , ChangePoints.timeOf 4 index
                    ]
                        |> Expect.equal [ Just 1000, Just 6000, Nothing ]
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
                        |> List.map (\elapsed -> ChangePoints.valueAt elapsed longIndex)
                        |> Expect.equal (List.map scanValue samples)
            , test "counts the same changes a linear scan would" <|
                \_ ->
                    samples
                        |> List.map (\elapsed -> ChangePoints.countUpTo elapsed longIndex)
                        |> Expect.equal (List.map scanCount samples)
            ]
        ]



-- FIXTURE


index : ChangePoints String
index =
    ChangePoints.fromList
        [ ( 1000, "a" )
        , ( 3000, "b" )
        , ( 5000, "c" )
        , ( 6000, "d" )
        ]


emptyIndex : ChangePoints String
emptyIndex =
    ChangePoints.empty


longChanges : List ( Duration, Int )
longChanges =
    List.range 1 200 |> List.map (\i -> ( i * 1000, i ))


longIndex : ChangePoints Int
longIndex =
    ChangePoints.fromList longChanges


samples : List Duration
samples =
    List.range 0 402 |> List.map (\i -> i * 500)



-- THE SPECIFICATION THE SEARCH IMPLEMENTS


upTo : Duration -> List ( Duration, Int )
upTo elapsed =
    List.filter (\( at, _ ) -> at <= elapsed) longChanges


scanValue : Duration -> Maybe Int
scanValue elapsed =
    upTo elapsed
        |> List.reverse
        |> List.head
        |> Maybe.map Tuple.second


scanCount : Duration -> Int
scanCount elapsed =
    List.length (upTo elapsed)
