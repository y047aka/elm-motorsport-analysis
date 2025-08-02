module Motorsport.LapExtractorTest exposing (suite)

import Expect
import Motorsport.Car exposing (Status(..))
import Motorsport.Class as Class exposing (Class(..))
import Motorsport.Driver exposing (Driver)
import Motorsport.LapExtractor as LapExtractor
import Motorsport.Manufacturer exposing (Manufacturer(..))
import Motorsport.TimelineEvent exposing (CarEventType(..), EventType(..))
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "LapExtractor"
        [ test "extractLapsFromTimelineEvents should extract laps from Start and LapCompleted events" <|
            \_ ->
                let
                    -- テスト用のタイムラインイベント
                    timelineEvents =
                        [ { eventTime = 0
                          , eventType =
                                CarEvent "007"
                                    (Start
                                        { currentLap =
                                            { carNumber = "007"
                                            , driver = Driver "Driver A"
                                            , lap = 1
                                            , position = Just 1
                                            , time = 95365 -- 1:35.365
                                            , best = 95365
                                            , sector_1 = 23155
                                            , sector_2 = 29928
                                            , sector_3 = 42282
                                            , s1_best = 23155
                                            , s2_best = 29928
                                            , s3_best = 42282
                                            , elapsed = 95365
                                            , miniSectors = Nothing
                                            }
                                        }
                                    )
                          }
                        , { eventTime = 95365
                          , eventType =
                                CarEvent "007"
                                    (LapCompleted 1
                                        { nextLap =
                                            { carNumber = "007"
                                            , driver = Driver "Driver A"
                                            , lap = 2
                                            , position = Just 1
                                            , time = 94210 -- 1:34.210
                                            , best = 94210
                                            , sector_1 = 23000
                                            , sector_2 = 29000
                                            , sector_3 = 42210
                                            , s1_best = 23000
                                            , s2_best = 29000
                                            , s3_best = 42210
                                            , elapsed = 189575 -- 3:09.575
                                            , miniSectors = Nothing
                                            }
                                        }
                                    )
                          }
                        ]

                    -- テスト用の車両（lapsが空）
                    cars =
                        [ { metadata =
                                { carNumber = "007"
                                , drivers = [ Driver "Driver A" ]
                                , class = Class.none
                                , group = "H"
                                , team = "Test Team"
                                , manufacturer = Other
                                }
                          , startPosition = 1
                          , laps = [] -- 空のリスト
                          , currentLap = Nothing
                          , lastLap = Nothing
                          , status = PreRace
                          , currentDriver = Nothing
                          }
                        ]

                    -- LapExtractorを実行
                    result =
                        LapExtractor.extractLapsFromTimelineEvents timelineEvents cars

                    extractedCar =
                        List.head result
                in
                case extractedCar of
                    Just car ->
                        Expect.all
                            [ \() -> Expect.equal 2 (List.length car.laps)
                            , \() ->
                                case List.head car.laps of
                                    Just firstLap ->
                                        Expect.equal 1 firstLap.lap

                                    Nothing ->
                                        Expect.fail "First lap should exist"
                            , \() ->
                                case car.laps |> List.drop 1 |> List.head of
                                    Just secondLap ->
                                        Expect.equal 2 secondLap.lap

                                    Nothing ->
                                        Expect.fail "Second lap should exist"
                            ]
                            ()

                    Nothing ->
                        Expect.fail "Car should exist in result"
        ]
