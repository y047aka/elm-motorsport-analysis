module Data.Analysis exposing (Analysis, History, analysisDecoder, standings)

import Data.Driver exposing (Driver)
import Data.Lap exposing (Lap, fastest, fromWithoutElapsed)
import Data.Lap.WithoutElapsed as Lap
import Data.RaceSummary exposing (RaceSummary, raceSummaryDecoder)
import Json.Decode as Decode exposing (field, int, maybe, string)



-- TYPE


type alias Analysis =
    { summary : RaceSummary
    , raceHistories : List History
    }


type alias History =
    { carNumber : String
    , driver : Driver
    , laps : List Lap
    , pitStops : List Int
    , fastestLap : Lap
    }



-- DECODER


analysisDecoder : Decode.Decoder Analysis
analysisDecoder =
    Decode.map2 toAnalysis
        raceSummaryDecoder
        (field "raceHistory" (Decode.list historyDecoder))


toAnalysis : RaceSummary -> List History -> Analysis
toAnalysis summary raceHistories =
    { summary = summary
    , raceHistories = standings summary.drivers raceHistories
    }


historyDecoder : Decode.Decoder History
historyDecoder =
    Decode.map3 toHistory
        (field "car" string)
        (field "lapTime" (Decode.list Lap.withoutElapsedDecoder))
        (maybe <| field "pit" (Decode.list int))


toHistory : String -> List Lap.WithoutElapsed -> Maybe (List Int) -> History
toHistory carNumber laps maybePitStops =
    { carNumber = carNumber
    , driver = Driver "" "" "" "" ""
    , laps = fromWithoutElapsed laps
    , pitStops = Maybe.withDefault [] maybePitStops
    , fastestLap =
        fastest laps
            |> Maybe.withDefault (Lap.WithoutElapsed 0 0)
            |> (\{ lapCount, time } -> Lap lapCount time 0)
    }



-- HELPER


standings : List Driver -> List History -> List History
standings drivers raceHistories =
    drivers
        |> List.map
            (\driver ->
                let
                    history =
                        raceHistories
                            |> List.filter (\{ carNumber } -> driver.carNumber == carNumber)
                            |> List.head
                            |> Maybe.withDefault (History "" (Driver "" "" "" "" "") [] [] (Lap 0 0 0))
                in
                { driver = driver
                , carNumber = history.carNumber
                , laps = history.laps
                , pitStops = history.pitStops
                , fastestLap = history.fastestLap
                }
            )
