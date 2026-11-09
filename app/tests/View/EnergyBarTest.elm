module View.EnergyBarTest exposing (suite)

import Expect
import Motorsport.Analysis.Energy as Energy
import Test exposing (Test, describe, test)
import View.EnergyBar as EnergyBar exposing (Stage(..))


level : Int -> Int -> Energy.Level
level laps window =
    { laps = laps
    , window = window
    , band = 1
    , fraction = toFloat laps / toFloat window
    }


suite : Test
suite =
    describe "View.EnergyBar"
        [ describe "the level the fill is drawn in, counted in quarters of the window"
            [ test "a whole window left is the fullest level" <|
                \_ ->
                    EnergyBar.stageOf (level 14 14) |> Expect.equal Ample
            , test "three quarters of the window is that level" <|
                \_ ->
                    EnergyBar.stageOf (level 11 14) |> Expect.equal Ample
            , test "the lap under three quarters is the next level down" <|
                \_ ->
                    EnergyBar.stageOf (level 10 14) |> Expect.equal Steady
            , test "half the window is that level" <|
                \_ ->
                    EnergyBar.stageOf (level 7 14) |> Expect.equal Steady
            , test "the lap under half is the next level down" <|
                \_ ->
                    EnergyBar.stageOf (level 6 14) |> Expect.equal Low
            , test "a quarter of the window is that level" <|
                \_ ->
                    EnergyBar.stageOf (level 4 14) |> Expect.equal Low
            , test "the lap inside the last quarter is the last level" <|
                \_ ->
                    EnergyBar.stageOf (level 3 14) |> Expect.equal Critical
            , test "nothing left is the last level" <|
                \_ ->
                    EnergyBar.stageOf (level 0 14) |> Expect.equal Critical
            ]
        , describe "the window the quarters are of"
            [ test "twelve laps of a twelve-lap window is the fullest level" <|
                \_ ->
                    EnergyBar.stageOf (level 12 12) |> Expect.equal Ample
            , test "twelve laps of a twenty-four-lap window is half, whatever the lap count" <|
                \_ ->
                    EnergyBar.stageOf (level 12 24) |> Expect.equal Steady
            ]
        ]
