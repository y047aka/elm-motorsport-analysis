module Motorsport.RaceControl.ViewModelTest exposing (suite)

import Expect
import Motorsport.Car as Car exposing (Status(..))
import Motorsport.Class as Class
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap(..))
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Ordering as Ordering
import Motorsport.RaceControl.ViewModel as ViewModel exposing (Timing, ViewModelItem)
import SortedList
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

                        sortedItems =
                            Ordering.byPosition items

                        viewModel =
                            { leadLapNumber = List.head items |> Maybe.map .lap |> Maybe.withDefault 0
                            , items = sortedItems
                            , itemsByClass =
                                sortedItems
                                    |> SortedList.gatherEqualsBy (.metadata >> .class)
                                    |> List.map (\( first, rest ) -> ( first.metadata.class, Ordering.byPosition (first :: SortedList.toList rest) ))
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

                        sortedItems =
                            Ordering.byPosition items

                        viewModel =
                            { leadLapNumber = List.head items |> Maybe.map .lap |> Maybe.withDefault 0
                            , items = sortedItems
                            , itemsByClass =
                                sortedItems
                                    |> SortedList.gatherEqualsBy (.metadata >> .class)
                                    |> List.map (\( first, rest ) -> ( first.metadata.class, Ordering.byPosition (first :: SortedList.toList rest) ))
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

                        sortedItems =
                            Ordering.byPosition items

                        viewModel =
                            { leadLapNumber = List.head items |> Maybe.map .lap |> Maybe.withDefault 0
                            , items = sortedItems
                            , itemsByClass =
                                sortedItems
                                    |> SortedList.gatherEqualsBy (.metadata >> .class)
                                    |> List.map (\( first, rest ) -> ( first.metadata.class, Ordering.byPosition (first :: SortedList.toList rest) ))
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
    , metadata = createMetadata carNumber
    , lap = 5
    , timing = createTiming gap
    , currentLap = Nothing
    , lastLap = Nothing
    , history = []
    }


createMetadata : String -> Car.Metadata
createMetadata carNumber =
    { carNumber = carNumber
    , class = Class.none
    , group = "Test Group"
    , team = "Test Team"
    , drivers = [ createDriver "Test Driver" ]
    , manufacturer = Manufacturer.Other
    }


createDriver : String -> Driver
createDriver name =
    { name = name }


createTiming : Gap -> Timing
createTiming gap =
    { time = 90000 -- 1:30.000
    , sector = Nothing
    , miniSector = Nothing
    , gap = Gap.None
    , interval = gap
    }
