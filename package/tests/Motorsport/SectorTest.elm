module Motorsport.SectorTest exposing (tests)

import Expect
import Motorsport.Sector as Sector exposing (Sector(..))
import Test exposing (..)


tests : Test
tests =
    describe "Motorsport.Sector"
        [ describe "compare"
            [ test "orders `all` the way a car drives it" <|
                \_ ->
                    List.sortWith Sector.compare [ S3, S1, S2 ]
                        |> Expect.equal Sector.all
            , test "is reflexive" <|
                \_ ->
                    Sector.all
                        |> List.map (\sector -> Sector.compare sector sector)
                        |> Expect.equal [ EQ, EQ, EQ ]
            , test "is antisymmetric" <|
                \_ ->
                    pairs Sector.all
                        |> List.map (\( a, b ) -> ( Sector.compare a b, Sector.compare b a ))
                        |> List.filter (\( ab, ba ) -> ab /= flip ba)
                        |> Expect.equalLists []
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
