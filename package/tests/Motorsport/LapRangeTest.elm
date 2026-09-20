module Motorsport.LapRangeTest exposing (suite)

import Expect
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.LapRange as LapRange
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Motorsport.LapRange"
        [ test "both ends are inside the range" <|
            \_ ->
                LapRange.within { first = 2, last = 4 } (List.map lapNumbered (List.range 1 5))
                    |> List.map .lap
                    |> Expect.equal [ 2, 3, 4 ]
        , test "a range of one lap keeps that lap" <|
            \_ ->
                LapRange.within { first = 3, last = 3 } (List.map lapNumbered (List.range 1 5))
                    |> List.map .lap
                    |> Expect.equal [ 3 ]
        , test "a range the car never reached keeps none of them" <|
            \_ ->
                LapRange.within { first = 9, last = 12 } (List.map lapNumbered (List.range 1 5))
                    |> Expect.equal []
        ]



-- FIXTURE


lapNumbered : Int -> Lap
lapNumbered lapNumber =
    { emptyLap | lap = lapNumber }


emptyLap : Lap
emptyLap =
    Lap.empty
