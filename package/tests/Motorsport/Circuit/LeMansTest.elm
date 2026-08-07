module Motorsport.Circuit.LeMansTest exposing (tests)

import Expect
import Motorsport.Circuit.LeMans as LeMans
import Motorsport.Sector as Sector
import Test exposing (..)


tests : Test
tests =
    describe "Motorsport.Circuit.LeMans"
        [ describe "compare"
            [ test "orders `all` the way a car drives it" <|
                \_ ->
                    List.sortWith LeMans.compare (List.reverse LeMans.all)
                        |> Expect.equal LeMans.all
            , test "is reflexive" <|
                \_ ->
                    LeMans.all
                        |> List.map (\mini -> LeMans.compare mini mini)
                        |> Expect.equal (List.repeat 15 EQ)
            , test "is antisymmetric" <|
                \_ ->
                    pairs LeMans.all
                        |> List.map (\( a, b ) -> ( LeMans.compare a b, LeMans.compare b a ))
                        |> List.filter (\( ab, ba ) -> ab /= flip ba)
                        |> Expect.equalLists []
            , test "separates every mini sector from every other" <|
                \_ ->
                    -- The one thing a hand-written index can get wrong that the
                    -- compiler cannot catch: two constructors given the same
                    -- number would compare `EQ` and collapse into one another.
                    pairs LeMans.all
                        |> List.filter (\( a, b ) -> a /= b && LeMans.compare a b == EQ)
                        |> Expect.equalLists []
            ]
        , describe "layout"
            [ test "is `all`, cut into the three sectors and no more" <|
                \_ ->
                    -- The order is `all`'s to state and the layout's to group.
                    -- A mini sector dropped from the layout, listed twice, or
                    -- moved into a different sector shows up here rather than
                    -- as a track drawn wrong.
                    Sector.values LeMans.layout.sectors
                        |> List.concat
                        |> Expect.equal LeMans.all
            ]
        , describe "toList"
            [ test "pairs each value with the mini sector it was stored under" <|
                \_ ->
                    LeMans.initialize LeMans.toString
                        |> LeMans.toList
                        |> List.filter (\( mini, name ) -> name /= LeMans.toString mini)
                        |> Expect.equalLists []
            , test "reads out in track order" <|
                \_ ->
                    LeMans.initialize identity
                        |> LeMans.toList
                        |> List.map Tuple.first
                        |> Expect.equal LeMans.all
            ]
        ]


{-| Every ordered pair, including each element with itself.
-}
pairs : List a -> List ( a, a )
pairs xs =
    List.concatMap (\a -> List.map (Tuple.pair a) xs) xs


flip : Order -> Order
flip order =
    case order of
        LT ->
            GT

        EQ ->
            EQ

        GT ->
            LT
