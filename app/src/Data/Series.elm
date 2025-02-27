module Data.Series exposing (carImageUrl_Wec, toEventSummary)

import Data.Series.Wec exposing (EventSummary, Wec)
import Data.Series.Wec_2024 exposing (carImageFileName_2024, toEventSummary_Wec_2024)


toEventSummary : ( Int, Wec ) -> Maybe EventSummary
toEventSummary ( season, event ) =
    case season of
        2024 ->
            Just (toEventSummary_Wec_2024 event)

        _ ->
            Nothing


carImageUrl_Wec : String -> String -> Maybe String
carImageUrl_Wec season carNumber =
    let
        domain =
            "https://storage.googleapis.com"

        path =
            "/ecm-prod/media/cache/easy_thumb/assets/1/engage"
    in
    case season of
        "2024" ->
            carImageFileName_2024 carNumber
                -- |> Maybe.map (\fileName -> String.concat [ domain, path, fileName ])
                |> Maybe.map (\fileName -> String.concat [ "/static/image", String.dropLeft 6 fileName ])

        _ ->
            Nothing
