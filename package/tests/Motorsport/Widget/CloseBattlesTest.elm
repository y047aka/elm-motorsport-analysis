module Motorsport.Widget.CloseBattlesTest exposing (suite)

import Expect
import Motorsport.Car exposing (Status(..))
import Motorsport.Class as Class
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap(..))
import Motorsport.RaceControl.ViewModel exposing (MetaData, Timing, ViewModelItem)
import Motorsport.Widget.CloseBattles as CloseBattles
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "CloseBattles"
        [ describe "detectCloseBattles"
            [ test "detects battles when cars are within 1.5 seconds" <|
                \_ ->
                    let
                        viewModel =
                            [ createViewModelItem 1 "1" 1000 -- 1.0s gap
                            , createViewModelItem 2 "2" 500  -- 0.5s gap
                            , createViewModelItem 3 "3" 1200 -- 1.2s gap
                            ]
                    in
                    CloseBattles.detectCloseBattles viewModel
                        |> Expect.equal [ { cars = viewModel, position = 1 } ]

            , test "returns empty list when no cars are close" <|
                \_ ->
                    let
                        viewModel =
                            [ createViewModelItem 1 "1" 2000 -- 2.0s gap - too far
                            , createViewModelItem 2 "2" 2500 -- 2.5s gap - too far
                            , createViewModelItem 3 "3" 3000 -- 3.0s gap - too far
                            ]
                    in
                    CloseBattles.detectCloseBattles viewModel
                        |> Expect.equal []

            , test "filters out single car groups" <|
                \_ ->
                    let
                        viewModel =
                            [ createViewModelItem 1 "1" 1000 -- 1.0s gap
                            , createViewModelItem 2 "2" 2000 -- 2.0s gap - too far, creates single group
                            , createViewModelItem 3 "3" 500  -- 0.5s gap
                            ]
                    in
                    CloseBattles.detectCloseBattles viewModel
                        |> List.length
                        |> Expect.equal 1

            , test "handles multiple battle groups" <|
                \_ ->
                    let
                        viewModel =
                            [ createViewModelItem 1 "1" 1000 -- Group 1: positions 1-2
                            , createViewModelItem 2 "2" 1200
                            , createViewModelItem 3 "3" 2000 -- Gap - single car
                            , createViewModelItem 4 "4" 800  -- Group 2: positions 4-5
                            , createViewModelItem 5 "5" 1100
                            ]
                    in
                    CloseBattles.detectCloseBattles viewModel
                        |> List.length
                        |> Expect.equal 2

            ]

        , describe "groupConsecutiveCloseCars"
            [ test "groups cars with gaps <= 1.5 seconds" <|
                \_ ->
                    let
                        viewModel =
                            [ createViewModelItem 1 "1" 1000 -- 1.0s - close
                            , createViewModelItem 2 "2" 1500 -- 1.5s - close (boundary)
                            , createViewModelItem 3 "3" 1501 -- 1.501s - not close
                            ]
                    in
                    CloseBattles.groupConsecutiveCloseCars viewModel
                        |> Expect.equal
                            [ [ createViewModelItem 1 "1" 1000
                              , createViewModelItem 2 "2" 1500
                              ]
                            , [ createViewModelItem 3 "3" 1501 ]
                            ]

            , test "creates separate groups when gap is too large" <|
                \_ ->
                    let
                        viewModel =
                            [ createViewModelItem 1 "1" 1000 -- Group 1
                            , createViewModelItem 2 "2" 2000 -- Gap too large, starts Group 2
                            , createViewModelItem 3 "3" 1200 -- Continues Group 2
                            ]
                    in
                    CloseBattles.groupConsecutiveCloseCars viewModel
                        |> Expect.equal
                            [ [ createViewModelItem 1 "1" 1000 ]
                            , [ createViewModelItem 2 "2" 2000
                              , createViewModelItem 3 "3" 1200
                              ]
                            ]

            , test "handles non-Seconds gap types" <|
                \_ ->
                    let
                        viewModel =
                            [ createViewModelItem 1 "1" 1000
                            , createViewModelItemWithGap 2 "2" Gap.None
                            , createViewModelItemWithGap 3 "3" (Gap.Laps 1)
                            ]
                    in
                    CloseBattles.groupConsecutiveCloseCars viewModel
                        |> Expect.equal
                            [ [ createViewModelItem 1 "1" 1000 ]
                            , [ createViewModelItemWithGap 2 "2" Gap.None ]
                            , [ createViewModelItemWithGap 3 "3" (Gap.Laps 1) ]
                            ]

            ]
        ]


-- Helper functions for creating test data

createViewModelItem : Int -> String -> Duration -> ViewModelItem
createViewModelItem position carNumber interval =
    createViewModelItemWithGap position carNumber (Gap.Seconds interval)


createViewModelItemWithGap : Int -> String -> Gap -> ViewModelItem
createViewModelItemWithGap position carNumber gap =
    { position = position
    , positionInClass = 1
    , status = Racing
    , metaData = createMetaData carNumber
    , lap = 5
    , timing = createTiming gap
    , currentLap = Nothing
    , lastLap = Nothing
    , history = []
    }


createMetaData : String -> MetaData
createMetaData carNumber =
    { carNumber = carNumber
    , class = Class.none
    , team = "Test Team"
    , drivers = [ createDriver "Test Driver" ]
    }


createDriver : String -> Driver
createDriver name =
    { name = name
    , isCurrentDriver = True
    }


createTiming : Gap -> Timing
createTiming gap =
    { time = 90000 -- 1:30.000
    , sector = Nothing
    , miniSector = Nothing
    , gap = Gap.None
    , interval = gap
    }
