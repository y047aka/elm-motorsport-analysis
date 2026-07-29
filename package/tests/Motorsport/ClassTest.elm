module Motorsport.ClassTest exposing (tests)

import Expect
import List.Extra
import Motorsport.Class as Class exposing (Class)
import Test exposing (..)


tests : Test
tests =
    describe "Motorsport.Class"
        [ describe "compare"
            [ test "orders `all` fastest category first" <|
                \_ ->
                    List.sortWith Class.compare (List.reverse Class.all)
                        |> Expect.equal Class.all
            , test "is reflexive" <|
                \_ ->
                    everyClass
                        |> List.map (\class -> Class.compare class class)
                        |> List.filter ((/=) EQ)
                        |> Expect.equalLists []
            , test "is antisymmetric" <|
                \_ ->
                    pairs everyClass
                        |> List.map (\( a, b ) -> ( Class.compare a b, Class.compare b a ))
                        |> List.filter (\( ab, ba ) -> ab /= flip ba)
                        |> Expect.equalLists []
            , test "sorts `none` after every class that races" <|
                \_ ->
                    Class.all
                        |> List.map (\class -> Class.compare class Class.none)
                        |> List.filter ((/=) LT)
                        |> Expect.equalLists []
            , test "never calls two different classes equal" <|
                \_ ->
                    pairs everyClass
                        |> List.filter (\( a, b ) -> a /= b && Class.compare a b == EQ)
                        |> Expect.equalLists []
            ]
        , describe "fromString"
            [ test "reads back every name `toString` prints for a racing class" <|
                \_ ->
                    Class.all
                        |> List.map (Class.toString >> Class.fromString)
                        |> Expect.equalLists (List.map Just Class.all)
            , test "rejects the name of `none`, which marks missing data" <|
                \_ ->
                    Class.fromString (Class.toString Class.none)
                        |> Expect.equal Nothing
            , test "rejects a name no class goes by" <|
                \_ ->
                    -- The data prints "HYPERCAR"; nothing in it says LMH.
                    Class.fromString "LMH"
                        |> Expect.equal Nothing
            ]
        , describe "toString"
            [ test "gives every class a name of its own" <|
                \_ ->
                    let
                        names =
                            List.map Class.toString everyClass
                    in
                    List.Extra.unique names
                        |> Expect.equalLists names
            ]
        , describe "toColor"
            [ test "draws LMGT3 in the color of the LMGTE Am field it replaced, in its first season" <|
                \_ ->
                    colorOf 2024 "LMGT3"
                        |> Expect.equal (colorOf 2024 "LMGTE Am")
            , test "moves LMGT3 to the LMGTE Pro color once no GTE field is left to confuse it with" <|
                \_ ->
                    colorOf 2025 "LMGT3"
                        |> Expect.equal (colorOf 2025 "LMGTE Pro")
            , test "so the same class is drawn differently either side of 2024" <|
                \_ ->
                    colorOf 2025 "LMGT3"
                        |> Expect.notEqual (colorOf 2024 "LMGT3")
            , test "keeps the top category apart from LMP2" <|
                \_ ->
                    colorOf 2025 "HYPERCAR"
                        |> Expect.notEqual (colorOf 2025 "LMP2")
            ]
        ]


{-| Every class the type has a value for, `none` included -- ordering and
display have to hold for the placeholder too, and `all` leaves it out.
-}
everyClass : List Class
everyClass =
    Class.none :: Class.all


colorOf : Int -> String -> Maybe String
colorOf season name =
    Class.fromString name
        |> Maybe.map (Class.toColor { season = season } >> .value)


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
