module LapBenchmark exposing (main)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Motorsport.Duration exposing (fromStringWithDefault)
import Motorsport.Lap as Lap exposing (Lap)


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Lap" <|
        [ describe "compareAt"
            [ let
                clock =
                    { lapCount = 2, elapsed = carA.lap1.elapsed + 1 }
              in
              benchmark "Deffient lap"
                (\_ -> Lap.compareAt clock carA.lap2 carB.lap1)
            , let
                clock =
                    { lapCount = 2, elapsed = carA.lap1.elapsed + carA.lap2.sector_1 + 1 }
              in
              benchmark "Same lap, Deffient sector"
                (\_ -> Lap.compareAt clock carA.lap2 carB.lap2)
            , let
                clock =
                    { lapCount = 2, elapsed = carA.lap1.elapsed + carA.lap2.sector_1 - 1 }
              in
              benchmark "Same lap, Same sector"
                (\_ -> Lap.compareAt clock carA.lap2 carB.lap2)
            ]
        ]


carA : { lap1 : Lap, lap2 : Lap }
carA =
    let
        empty =
            Lap.empty
                |> (\lap -> { lap | carNumber = "2", driver = "Earl BAMBER", position = Just 1 })
    in
    { lap1 =
        { empty
            | lap = 1
            , time = "1:28.766" |> fromStringWithDefault 0
            , sector_1 = 20467
            , sector_2 = 28365
            , sector_3 = 39934
            , elapsed = "1:28.766" |> fromStringWithDefault 0
        }
    , lap2 =
        { empty
            | lap = 2
            , time = "1:48.431" |> fromStringWithDefault 0
            , sector_1 = 22414
            , sector_2 = 28076
            , sector_3 = 57941
            , elapsed = "3:17.197" |> fromStringWithDefault 0
        }
    }


carB : { lap1 : Lap, lap2 : Lap }
carB =
    let
        empty =
            Lap.empty
                |> (\lap -> { lap | carNumber = "15", driver = "Marco WITTMANN", position = Just 2 })
    in
    { lap1 =
        { empty
            | lap = 1
            , time = "1:30.152" |> fromStringWithDefault 0
            , sector_1 = 20905
            , sector_2 = 28914
            , sector_3 = 40333
            , elapsed = "1:30.152" |> fromStringWithDefault 0
        }
    , lap2 =
        { empty
            | lap = 2
            , position = Nothing
            , time = "1:47.691" |> fromStringWithDefault 0
            , sector_1 = 22444
            , sector_2 = 28484
            , sector_3 = 56763
            , elapsed = "3:17.843" |> fromStringWithDefault 0
        }
    }
