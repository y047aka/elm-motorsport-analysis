module Data.Series exposing (carImageUrl_Wec, toEventSummary)

import Data.Series.EventSummary exposing (EventSummary)
import Data.Series.Wec exposing (Wec)
import Data.Series.Wec_2024 exposing (carImageFileName_2024, toEventSummary_Wec_2024)
import Data.Series.Wec_2025 exposing (carImageFileName_2025, toEventSummary_Wec_2025)
import Data.Series.Wec_2026 exposing (carImageFileName_2026, toEventSummary_Wec_2026)
import Motorsport.Class.Era as Era


{-| The event, if the app can show it: it needs a table for the season and an
era to read that season's classes against.

Requiring the era keeps the seasons that load a subset of the seasons whose
grid is known -- a table added without its era resolves to `Nothing` instead of
loading with every class read against whichever grid is current.

-}
toEventSummary : ( Int, Wec ) -> Maybe EventSummary
toEventSummary ( season, event ) =
    Era.fromSeason season
        |> Maybe.andThen (\_ -> forSeason season event)


forSeason : Int -> Wec -> Maybe EventSummary
forSeason season event =
    case season of
        2024 ->
            Just (toEventSummary_Wec_2024 event)

        2025 ->
            Just (toEventSummary_Wec_2025 event)

        2026 ->
            Just (toEventSummary_Wec_2026 event)

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

        2026 ->
            carImageFileName_2026 carNumber
                |> Maybe.map (\fileName -> String.concat [ "/static/images/wec/2026", String.dropLeft 6 fileName ])

        _ ->
            Nothing
