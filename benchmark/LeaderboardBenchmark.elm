module LeaderboardBenchmark exposing (main)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Csv.Decode exposing (FieldNames(..))
import Fixture
import Motorsport.Analysis as Analysis exposing (Analysis)
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (LeaderboardItem, bestTimeColumn, carNumberColumn_Wec, customColumn, driverAndTeamColumn_Wec, histogramColumn, initialSort, intColumn, lastLapColumn, performanceColumn, sectorTimeColumn)
import Motorsport.RaceControl as RaceControl


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Leaderboard"
        [ benchmark "init"
            (\_ ->
                -- 94,535 runs/s (GoF: 99.99%)
                let
                    rc =
                        RaceControl.init Fixture.preprocessed
                in
                Leaderboard.init rc
            )
        , benchmark "view"
            (\_ ->
                -- 4,263 runs/s (GoF: 99.98%)
                let
                    rc =
                        RaceControl.init Fixture.preprocessed

                    analysis =
                        Analysis.finished rc
                in
                Leaderboard.view (config analysis) (initialSort "Position") rc
            )
        ]


type Msg
    = NoOp


config : Analysis -> Leaderboard.Config LeaderboardItem Msg
config analysis =
    { toId = .carNumber
    , toMsg = \_ -> NoOp
    , columns =
        [ intColumn { label = "", getter = .position }
        , carNumberColumn_Wec { carNumber = .carNumber, class = .class }
        , driverAndTeamColumn_Wec
        , intColumn { label = "Lap", getter = .lap }
        , customColumn
            { label = "Gap"
            , getter = .gap >> Gap.toString
            , sorter = List.sortBy .position
            }
        , customColumn
            { label = "Interval"
            , getter = .interval >> Gap.toString
            , sorter = List.sortBy .position
            }
        , sectorTimeColumn
            { label = "S1"
            , getter = \{ sector_1, s1_best } -> { time = sector_1, best = s1_best }
            , fastestSectorTime = analysis.sector_1_fastest
            }
        , sectorTimeColumn
            { label = "S2"
            , getter = \{ sector_2, s2_best } -> { time = sector_2, best = s2_best }
            , fastestSectorTime = analysis.sector_2_fastest
            }
        , sectorTimeColumn
            { label = "S3"
            , getter = \{ sector_3, s3_best } -> { time = sector_3, best = s3_best }
            , fastestSectorTime = analysis.sector_3_fastest
            }
        , lastLapColumn
            { getter = identity
            , sorter = List.sortBy .lastLapTime
            , analysis = analysis
            }
        , bestTimeColumn { getter = .best }
        , performanceColumn
            { getter = .history
            , sorter = List.sortBy .lastLapTime
            , analysis = analysis
            }
        , histogramColumn
            { getter = .history
            , sorter = List.sortBy .lastLapTime
            , analysis = analysis
            , coefficient = 1.2
            }
        ]
    }
