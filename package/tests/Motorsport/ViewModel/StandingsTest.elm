module Motorsport.ViewModel.StandingsTest exposing (suite)

import Expect
import Motorsport.Class as Class
import Motorsport.Driver as Driver
import Motorsport.Duration exposing (Duration)
import Motorsport.Gap as Gap exposing (Gap)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race.Entrant as Entrant
import Motorsport.Sector as Sector exposing (Sector(..))
import Motorsport.Status exposing (Status(..))
import Motorsport.ViewModel.Entry exposing (Entry)
import Motorsport.ViewModel.Standings as Standings
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "Standings"
        [ describe "currentLapSectors"
            [ test "keeps each sector's time and personal best with the sector they belong to" <|
                \_ ->
                    Standings.fromLaps (createMetadata "1") [ sectorFixtureLap ]
                        |> Standings.toList
                        |> List.head
                        |> Maybe.andThen .currentLapSectors
                        |> Maybe.map Sector.toList
                        |> Expect.equal
                            (Just
                                [ ( S1, { time = 1000, personalBest = 900 } )
                                , ( S2, { time = 2000, personalBest = 1900 } )
                                , ( S3, { time = 3000, personalBest = 2900 } )
                                ]
                            )
            ]
        , describe "groupCarsByCloseIntervals"
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
                            , createStandingsEntryWithGap 2 "2" Gap.none
                            , createStandingsEntryWithGap 3 "3" (Gap.laps 1)
                            ]

                    in
                    Standings.groupCarsByCloseIntervals (Standings.fromList entries)
                        |> Expect.equal []
            ]
        ]



-- Helper functions for creating test data


createStandingsEntry : Int -> String -> Duration -> Entry
createStandingsEntry position carNumber interval =
    createStandingsEntryWithGap position carNumber (Gap.seconds interval)


createStandingsEntryWithGap : Int -> String -> Gap -> Entry
createStandingsEntryWithGap position carNumber gap =
    { position = position
    , positionInClass = 1
    , status = Racing
    , metadata = createMetadata carNumber
    , classColor = (Class.toColor Class.none).value
    , lapsCompleted = 5
    , currentLapTime = Nothing
    , currentLapBest = Nothing
    , currentLapSectors = Nothing
    , currentLapSectorStates = Nothing
    , currentLapMiniSectors = Nothing
    , currentLapElapsed = 90000 -- 1:30.000
    , currentLapRated = Nothing
    , sector = Nothing
    , miniSector = Nothing
    , gapToLeader = Gap.none
    , intervalToAhead = gap
    , currentLapProgress = 0
    , lastLapRated = Nothing
    , bestLapRated = Nothing
    , lastLapSectors = Nothing
    , lastLapMiniSectors = Nothing
    , currentDriver = Nothing
    }


createMetadata : String -> Entrant.Metadata
createMetadata carNumber =
    { carNumber = carNumber
    , class = Class.none
    , group = "Test Group"
    , team = "Test Team"
    , drivers = [ Driver.fromName "Test Driver" ]
    , manufacturer = Manufacturer.Other
    }


{-| Distinct times and bests per sector, so a mix-up between them shows up.
-}
sectorFixtureLap : Lap
sectorFixtureLap =
    { empty
        | lap = 1
        , time = 6000
        , elapsed = 6000
        , sectors =
            { s1 = { time = 1000, personalBest = 900 }
            , s2 = { time = 2000, personalBest = 1900 }
            , s3 = { time = 3000, personalBest = 2900 }
            }
    }


empty : Lap
empty =
    Lap.empty
