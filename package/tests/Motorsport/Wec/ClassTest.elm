module Motorsport.Wec.ClassTest exposing (tests)

import Expect
import List.Extra
import Motorsport.Class as Class exposing (Class)
import Motorsport.Wec.Class as WecClass
import Motorsport.Wec.Era as Era exposing (Era)
import Test exposing (..)


tests : Test
tests =
    describe "Motorsport.Wec.Class"
        [ describe "grid"
            [ test "is the grid each era actually ran" <|
                \_ ->
                    everyEra
                        |> List.map (WecClass.grid >> List.map .name)
                        |> Expect.equalLists
                            [ [ "HYPERCAR", "LMP2", "LMGTE Pro", "LMGTE Am" ]
                            , [ "HYPERCAR", "LMP2", "LMGTE Am" ]
                            , [ "HYPERCAR", "LMP2", "LMGT3" ]
                            , [ "HYPERCAR", "LMP2", "LMGT3" ]
                            ]
            , test "lists no class under the name `none` goes by" <|
                \_ ->
                    everyEra
                        |> List.filter (\era -> List.member (Class.toString Class.none) (List.map .name (WecClass.grid era)))
                        |> Expect.equalLists []
            , test "gives each class on a grid a color of its own" <|
                \_ ->
                    WecClass.grid Era.GteProAndAm
                        |> List.map .color
                        |> List.Extra.unique
                        |> Expect.equalLists (WecClass.grid Era.GteProAndAm |> List.map .color)
            ]
        , describe "classesOf"
            [ test "keeps the grid's own order, whatever it is sorted from" <|
                \_ ->
                    everyEra
                        |> List.map
                            (\era ->
                                List.sortWith Class.compare (List.reverse (classesOf era))
                            )
                        |> Expect.equalLists (List.map classesOf everyEra)
            ]
        , describe "fromString"
            [ test "reads back every name `toString` prints for the era's own classes" <|
                \_ ->
                    everyEra
                        |> List.map
                            (\era ->
                                classesOf era
                                    |> List.map (Class.toString >> Class.fromString (WecClass.grid era))
                            )
                        |> Expect.equalLists (List.map classesOf everyEra)
            , test "reads a class that belongs to another era as `none`" <|
                \_ ->
                    -- An LMGTE Am in a 2025 file is bad data: that grid does
                    -- not list it, so there is nothing to draw it as.
                    classIn Era.Gt3AsThirdClass "LMGTE Am"
                        |> Expect.equal Class.none
            , test "reads that same name as a class in the era that ran it" <|
                \_ ->
                    classIn Era.GteProAndAm "LMGTE Am"
                        |> Expect.notEqual Class.none
            , test "settles order and color, so the same name reads differently in two eras" <|
                \_ ->
                    -- LMGT3 came fourth in 2024 and third in 2025: two distinct values.
                    classIn Era.Gt3AsFourthClass "LMGT3"
                        |> Expect.notEqual (classIn Era.Gt3AsThirdClass "LMGT3")
            , test "reads the name of `none` back as `none`" <|
                \_ ->
                    everyEra
                        |> List.map (\era -> Class.fromString (WecClass.grid era) (Class.toString Class.none))
                        |> List.filter ((/=) Class.none)
                        |> Expect.equalLists []
            , test "reads a name no class goes by as `none`" <|
                \_ ->
                    -- The data prints "HYPERCAR"; nothing in it says LMH.
                    classIn Era.Gt3AsThirdClass "LMH"
                        |> Expect.equal Class.none
            ]
        , describe "toString"
            [ test "keeps a category's name across the eras it raced in" <|
                \_ ->
                    -- LMGT3 changed place between 2024 and 2025, not name.
                    [ classIn Era.Gt3AsFourthClass "LMGT3", classIn Era.Gt3AsThirdClass "LMGT3" ]
                        |> List.map Class.toString
                        |> Expect.equalLists [ "LMGT3", "LMGT3" ]
            ]
        , describe "compare"
            [ test "sorts a class by where it came on its own grid, whatever it is compared against" <|
                \_ ->
                    -- LMGTE Am came last in 2021; nothing on the 2025 grid is behind it.
                    classesOf Era.Gt3AsThirdClass
                        |> List.map (\class -> Class.compare class gteAm)
                        |> List.filter ((/=) LT)
                        |> Expect.equalLists []
            ]
        , describe "toColor"
            [ test "draws a class in the color its own era's grid gives it" <|
                \_ ->
                    -- Third has been green since LMGTE Pro held it, fourth
                    -- orange since LMGTE Am did.
                    [ colorOf 2021 "LMGTE Pro", colorOf 2021 "LMGTE Am" ]
                        |> Expect.equalLists [ Just green, Just orange ]
            , test "keeps LMGTE Am fourth in 2023, where third stood empty" <|
                \_ ->
                    -- LMGTE Pro was dropped, but Am did not move up.
                    colorOf 2023 "LMGTE Am"
                        |> Expect.equal (Just orange)
            , test "hands fourth to LMGT3 in 2024, then moves it up to third" <|
                \_ ->
                    [ colorOf 2024 "LMGT3", colorOf 2025 "LMGT3" ]
                        |> Expect.equalLists [ Just orange, Just green ]
            , test "hands a color on to the category that takes over the position" <|
                \_ ->
                    -- LMGT3 inherited LMGTE Am's color with its position in
                    -- 2024, and LMGTE Pro's in 2025.
                    [ colorOf 2024 "LMGT3" == colorOf 2021 "LMGTE Am"
                    , colorOf 2025 "LMGT3" == colorOf 2021 "LMGTE Pro"
                    ]
                        |> Expect.equalLists [ True, True ]
            , test "leaves the categories that never moved alone" <|
                \_ ->
                    [ 2021, 2023, 2024, 2025, 2030 ]
                        |> List.concatMap (\season -> [ colorOf season "HYPERCAR", colorOf season "LMP2" ])
                        |> List.Extra.unique
                        |> List.length
                        |> Expect.equal 2
            ]
        ]


{-| Every era, so the grids are checked in all of them rather than in whichever
one happens to be current. In the order `grid` is asserted against.
-}
everyEra : List Era
everyEra =
    [ Era.GteProAndAm
    , Era.GteAmAsFourthClass
    , Era.Gt3AsFourthClass
    , Era.Gt3AsThirdClass
    ]


classesOf : Era -> List Class
classesOf era =
    Class.classesOf (WecClass.grid era)


classIn : Era -> String -> Class
classIn era name =
    Class.fromString (WecClass.grid era) name


{-| LMGTE Am, as it stood while it was still racing.
-}
gteAm : Class
gteAm =
    classIn Era.GteProAndAm "LMGTE Am"


colorOf : Int -> String -> Maybe String
colorOf season name =
    Era.fromSeason season
        |> Maybe.map (\era -> classIn era name |> Class.toColor)


green : String
green =
    "oklch(50% 0.25 142)"


orange : String
orange =
    "oklch(70% 0.2 43)"
