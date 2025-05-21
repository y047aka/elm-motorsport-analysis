module Data.Series exposing (carImageUrl_Wec, toEventSummary, toEventSummary_FormulaE)

import Data.Series.FormulaE as FormulaE exposing (FormulaE)
import Data.Series.FormulaE_2025 exposing (toEventSummary_FormulaE_2025)
import Data.Series.Wec exposing (EventSummary, Wec)
import Data.Series.Wec_2024 exposing (carImageFileName_2024, toEventSummary_Wec_2024)
import Data.Series.Wec_2025 exposing (carImageFileName_2025, toEventSummary_Wec_2025)


toEventSummary : ( Int, Wec ) -> Maybe EventSummary
toEventSummary ( season, event ) =
    case season of
        2024 ->
            Just (toEventSummary_Wec_2024 event)

        2025 ->
            Just (toEventSummary_Wec_2025 event)

        _ ->
            Nothing


toEventSummary_FormulaE : ( Int, FormulaE ) -> Maybe FormulaE.EventSummary
toEventSummary_FormulaE ( season, event ) =
    case season of
        2025 ->
            Just (toEventSummary_FormulaE_2025 event)

        _ ->
            Nothing


carImageUrl_Wec : Int -> String -> Maybe String
carImageUrl_Wec season carNumber =
    let
        domain =
            "https://storage.googleapis.com"

        path =
            "/ecm-prod/media/cache/easy_thumb/assets/1/engage"
    in
    case season of
        2024 ->
            carImageFileName_2024 carNumber
                -- |> Maybe.map (\fileName -> String.concat [ domain, path, fileName ])
                |> Maybe.map (\fileName -> String.concat [ "/static/images/wec/2024", String.dropLeft 6 fileName ])

        2025 ->
            carImageFileName_2025 carNumber
                |> Maybe.map (\fileName -> String.concat [ "/static/images/wec/2025", String.dropLeft 6 fileName ])

        _ ->
            Nothing
