module Motorsport.Wec.EraTest exposing (tests)

import Expect
import Motorsport.Wec.Era as Era
import Test exposing (..)


tests : Test
tests =
    describe "Motorsport.Wec.Era"
        [ describe "fromSeason"
            [ test "resolves each season whose grid the app knows" <|
                \_ ->
                    [ 2021, 2022, 2023, 2024, 2025, 2026 ]
                        |> List.map Era.fromSeason
                        |> Expect.equalLists
                            [ Just Era.GteProAndAm
                            , Just Era.GteProAndAm
                            , Just Era.GteAmAsFourthClass
                            , Just Era.Gt3AsFourthClass
                            , Just Era.Gt3AsThirdClass
                            , Just Era.Gt3AsThirdClass
                            ]
            , test "needs no entry for a season the calendar has not reached" <|
                \_ ->
                    -- The point of eras: a new season is not a code change
                    -- unless the grid itself changed.
                    Era.fromSeason 2030
                        |> Expect.equal (Just Era.Gt3AsThirdClass)
            , test "has no answer for a season whose grid the app never sees" <|
                \_ ->
                    -- 2020 and earlier ran LMP1, which no era here covers.
                    [ 2020, 0, -1 ]
                        |> List.map Era.fromSeason
                        |> Expect.equalLists [ Nothing, Nothing, Nothing ]
            ]
        ]
