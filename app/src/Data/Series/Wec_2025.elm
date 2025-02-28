module Data.Series.Wec_2025 exposing (carImageFileName_2025, toEventSummary_Wec_2025, wec_2025)

import Data.Series.Wec exposing (EventSummary, Wec(..))


wec_2025 : List EventSummary
wec_2025 =
    List.map toEventSummary_Wec_2025
        [ Qatar_1812km ]


toEventSummary_Wec_2025 : Wec -> EventSummary
toEventSummary_Wec_2025 event =
    let
        id =
            Data.Series.Wec.toString event

        jsonPath =
            "/static/wec_2025/" ++ id ++ ".json"
    in
    case event of
        Qatar_1812km ->
            { id = id
            , name = "Qatar 1812km"
            , date = "2025-03-01"
            , jsonPath = jsonPath
            }

        -- TODO: Add more events
        _ ->
            { id = id
            , name = "Qatar 1812km"
            , date = "2025-03-01"
            , jsonPath = jsonPath
            }


carImageFileName_2025 : String -> Maybe String
carImageFileName_2025 carNumber =
    case carNumber of
        _ ->
            Nothing
