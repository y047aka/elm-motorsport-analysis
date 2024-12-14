module Leaderboard.Benchmark exposing (main)

import Benchmark exposing (Benchmark, benchmark, describe)
import Benchmark.Runner exposing (BenchmarkProgram, program)
import Csv.Decode exposing (FieldNames(..))
import Fixture
import Motorsport.Analysis as Analysis exposing (Analysis)
import Motorsport.Gap as Gap
import Motorsport.Leaderboard as Leaderboard exposing (bestTimeColumn, carNumberColumn_Wec, currentLapColumn_Wec, customColumn, driverAndTeamColumn_Wec, histogramColumn, initialSort, intColumn, lastLapColumn_Wec, performanceColumn)
import Motorsport.Leaderboard.ViewModel as ViewModel exposing (ViewModelItem)
import Motorsport.RaceControl as RaceControl exposing (Msg(..))


main : BenchmarkProgram
main =
    program suite


suite : Benchmark
suite =
    describe "Leaderboard"
        [ benchmark "init"
            (\_ ->
                -- 3,845 runs/s (GoF: 99.9%)
                let
                    rc =
                        RaceControl.init Fixture.preprocessed
                            |> RaceControl.update (SetCount (60 * 60 * 1000))
                in
                ViewModel.init rc
            )
        , benchmark "view"
            (\_ ->
                -- 591 runs/s (GoF: 99.97%)
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


config : Analysis -> Leaderboard.Config ViewModelItem Msg
config analysis =
    { toId = .metaData >> .carNumber
    , toMsg = \_ -> NoOp
    , columns =
        [ intColumn { label = "", getter = .position }
        , carNumberColumn_Wec { getter = .metaData }
        , driverAndTeamColumn_Wec { getter = .metaData }
        , intColumn { label = "Lap", getter = .lap }
        , customColumn
            { label = "Gap"
            , getter = .timing >> .gap >> Gap.toString
            , sorter = List.sortBy .position
            }
        , customColumn
            { label = "Interval"
            , getter = .timing >> .interval >> Gap.toString
            , sorter = List.sortBy .position
            }
        , currentLapColumn_Wec
            { getter = identity
            , sorter = List.sortBy (.currentLap >> Maybe.map .time >> Maybe.withDefault 0)
            , analysis = analysis
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
