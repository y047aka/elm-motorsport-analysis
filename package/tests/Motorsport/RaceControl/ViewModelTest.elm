module Motorsport.RaceControl.ViewModelTest exposing (suite)

import Expect
import Motorsport.Car exposing (Status(..))
import Motorsport.Class as Class
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap(..))
import Motorsport.RaceControl.ViewModel as ViewModel exposing (MetaData, Timing, ViewModelItem)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "CloseBattles"
        [ describe "groupCarsByCloseIntervals"
            [ test "groups cars with gaps <= 1.5 seconds" <|
                \_ ->
                    let
                        items =
                            [ createViewModelItem 1 "1" 1000 -- 1.0s - close
                            , createViewModelItem 2 "2" 1500 -- 1.5s - close (boundary)
                            , createViewModelItem 3 "3" 1501 -- 1.501s - not close
                            ]

                        viewModel =
                            { leadLapNumber = List.head items |> Maybe.map .lap |> Maybe.withDefault 0
                            , items = items
                            }
                    in
                    ViewModel.groupCarsByCloseIntervals viewModel
                        |> Expect.equal
                            [ [ createViewModelItem 1 "1" 1000
                              , createViewModelItem 2 "2" 1500
                              ]
                            ]
            , test "creates separate groups when gap is too large" <|
                \_ ->
                    let
                        items =
                            [ createViewModelItem 1 "1" 1000 -- Group 1
                            , createViewModelItem 2 "2" 2000 -- Gap too large, starts Group 2
                            , createViewModelItem 3 "3" 1200 -- Continues Group 2
                            ]

                        viewModel =
                            { leadLapNumber = List.head items |> Maybe.map .lap |> Maybe.withDefault 0
                            , items = items
                            }
                    in
                    ViewModel.groupCarsByCloseIntervals viewModel
                        |> Expect.equal
                            [ [ createViewModelItem 2 "2" 2000
                              , createViewModelItem 3 "3" 1200
                              ]
                            ]
            , test "handles non-Seconds gap types" <|
                \_ ->
                    let
                        items =
                            [ createViewModelItem 1 "1" 1000
                            , createViewModelItemWithGap 2 "2" Gap.None
                            , createViewModelItemWithGap 3 "3" (Gap.Laps 1)
                            ]

                        viewModel =
                            { leadLapNumber = List.head items |> Maybe.map .lap |> Maybe.withDefault 0
                            , items = items
                            }
                    in
                    ViewModel.groupCarsByCloseIntervals viewModel
                        |> Expect.equal []
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
