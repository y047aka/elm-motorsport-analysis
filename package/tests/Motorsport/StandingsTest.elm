module Motorsport.StandingsTest exposing (suite)

import Expect
import Motorsport.Car as Car exposing (Status(..))
import Motorsport.Class as Class
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap(..))
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Standings as Standings exposing (StandingsEntry)
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "CloseBattles"
        [ describe "groupCarsByCloseIntervals"
            [ test "groups cars with gaps <= 1.5 seconds" <|
                \_ ->
                    let
                        entries =
                            [ createStandingsEntry 1 "1" 1000 -- 1.0s - close
                            , createStandingsEntry 2 "2" 1500 -- 1.5s - close (boundary)
                            , createStandingsEntry 3 "3" 1501 -- 1.501s - not close
                            ]

                    in
                    Standings.groupCarsByCloseIntervals (Standings.fromList entries)
                        |> Expect.equal
                            [ [ createStandingsEntry 1 "1" 1000
                              , createStandingsEntry 2 "2" 1500
                              ]
                            ]
            , test "creates separate groups when gap is too large" <|
                \_ ->
                    let
                        entries =
                            [ createStandingsEntry 1 "1" 1000 -- Group 1
                            , createStandingsEntry 2 "2" 2000 -- Gap too large, starts Group 2
                            , createStandingsEntry 3 "3" 1200 -- Continues Group 2
                            ]

                    in
                    Standings.groupCarsByCloseIntervals (Standings.fromList entries)
                        |> Expect.equal
                            [ [ createStandingsEntry 2 "2" 2000
                              , createStandingsEntry 3 "3" 1200
                              ]
                            ]
            , test "handles non-Seconds gap types" <|
                \_ ->
                    let
                        entries =
                            [ createStandingsEntry 1 "1" 1000
                            , createStandingsEntryWithGap 2 "2" Gap.None
                            , createStandingsEntryWithGap 3 "3" (Gap.Laps 1)
                            ]

                    in
                    Standings.groupCarsByCloseIntervals (Standings.fromList entries)
                        |> Expect.equal []
            ]
        ]



-- Helper functions for creating test data


createStandingsEntry : Int -> String -> Duration -> StandingsEntry
createStandingsEntry position carNumber interval =
    createStandingsEntryWithGap position carNumber (Gap.Seconds interval)


createStandingsEntryWithGap : Int -> String -> Gap -> StandingsEntry
createStandingsEntryWithGap position carNumber gap =
    { position = position
    , positionInClass = 1
    , status = Racing
    , metadata = createMetadata carNumber
    , lapsCompleted = 5
    , currentLapTime = Nothing
    , currentLapBest = Nothing
    , currentLapSectors = Nothing
    , currentLapMiniSectors = Nothing
    , currentLapElapsed = 90000 -- 1:30.000
    , sector = Nothing
    , miniSector = Nothing
    , gapToLeader = Gap.None
    , intervalToAhead = gap
    , currentLapProgress = 0
    , lastLapTime = Nothing
    , bestLapTime = Nothing
    , lastLapSectors = Nothing
    , lastLapMiniSectors = Nothing
    , currentDriver = Nothing
    }


createMetadata : String -> Car.Metadata
createMetadata carNumber =
    { carNumber = carNumber
    , class = Class.none
    , group = "Test Group"
    , team = "Test Team"
    , drivers = [ Driver "Test Driver" ]
    , manufacturer = Manufacturer.Other
    }
