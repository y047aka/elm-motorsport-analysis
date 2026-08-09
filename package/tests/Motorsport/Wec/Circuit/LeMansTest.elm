module Motorsport.Wec.Circuit.LeMansTest exposing (tests)

import Expect
import Motorsport.Wec.Circuit.LeMans as LeMans
import Test exposing (..)


tests : Test
tests =
    describe "Motorsport.Wec.Circuit.LeMans"
        [ describe "compare"
            [ test "orders `all` the way a car drives it" <|
                \_ ->
                    List.sortWith LeMans.compare (List.reverse LeMans.all)
                        |> Expect.equal LeMans.all
            , test "separates every mini sector from every other" <|
                \_ ->
                    -- The one thing a hand-written index can get wrong that the
                    -- compiler cannot catch: two constructors given the same
                    -- number would compare `EQ` and collapse into one another.
                    pairs LeMans.all
                        |> List.filter (\( a, b ) -> a /= b && LeMans.compare a b == EQ)
                        |> Expect.equalLists []
            ]
        , describe "toList"
            [ test "reads every value out in track order, under the mini sector it was stored against" <|
                \_ ->
                    -- `get` and `initialize` are both fifteen-branch cases, so
                    -- a field wired to the wrong constructor in one of them
                    -- shows up here.
                    LeMans.initialize LeMans.toString
                        |> LeMans.toList
                        |> Expect.equal (List.map (\mini -> ( mini, LeMans.toString mini )) LeMans.all)
            ]
        ]


{-| Every ordered pair, including each element with itself.
-}
pairs : List a -> List ( a, a )
pairs xs =
    List.concatMap (\a -> List.map (Tuple.pair a) xs) xs
