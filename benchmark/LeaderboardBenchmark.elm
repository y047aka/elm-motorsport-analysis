module LeaderboardBenchmark exposing (main)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Csv.Decode exposing (FieldNames(..))
import Fixture
import Motorsport.Analysis as Analysis exposing (Analysis)
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (LeaderboardItem, bestTimeColumn, carNumberColumn_Wec, customColumn, driverAndTeamColumn_Wec, histogramColumn, initialSort, intColumn, lastLapColumn_Wec, performanceColumn, sectorTimeColumn)
import Motorsport.RaceControl as RaceControl exposing (Msg(..))


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Leaderboard"
        [ benchmark "init"
            (\_ ->
                -- 11,531 runs/s (GoF: 99.99%)
                let
                    rc =
                        RaceControl.init Fixture.preprocessed
                            |> RaceControl.update (SetCount (60 * 60 * 1000))
                in
                Leaderboard.init rc
            )
        , benchmark "view"
            (\_ ->
                -- 1,607 runs/s (GoF: 99.98%)
                let
                    rc =
                        RaceControl.init Fixture.preprocessed
                            |> RaceControl.update (SetCount (60 * 60 * 1000))

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
            , getter =
                .sector_1
                    >> Maybe.map
                        (\{ time, personalBest, inProgress } ->
                            { time = time
                            , personalBest = personalBest
                            , overallBest = analysis.sector_1_fastest
                            , inProgress = inProgress
                            }
                        )
            }
        , sectorTimeColumn
            { label = "S2"
            , getter =
                .sector_2
                    >> Maybe.map
                        (\{ time, personalBest, inProgress } ->
                            { time = time
                            , personalBest = personalBest
                            , overallBest = analysis.sector_2_fastest
                            , inProgress = inProgress
                            }
                        )
            }
        , sectorTimeColumn
            { label = "S3"
            , getter =
                .sector_3
                    >> Maybe.map
                        (\{ time, personalBest, inProgress } ->
                            { time = time
                            , personalBest = personalBest
                            , overallBest = analysis.sector_3_fastest
                            , inProgress = inProgress
                            }
                        )
            }
        , lastLapColumn_Wec
            { getter = .lastLap
            , sorter = List.sortBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , bestTimeColumn { getter = .lastLap >> Maybe.map .best }
        , performanceColumn
            { getter = .history
            , sorter = List.sortBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            }
        , histogramColumn
            { getter = .history
            , sorter = List.sortBy (.lastLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
            , coefficient = 1.2
            }
        ]
    }
