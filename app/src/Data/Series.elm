module Data.Series exposing (carImageUrl_Wec)

import Data.Series.Wec_2024 exposing (carImageFileName_2024)
import Data.Series.Wec_2025 exposing (carImageFileName_2025)
import Data.Series.Wec_2026 exposing (carImageFileName_2026)


{-| Where the car's image is served from.

The images were taken from
`https://storage.googleapis.com/ecm-prod/media/cache/easy_thumb/assets/1/engage`
and now sit under `/static/images/wec/<season>`. Each name there still carries
the asset id it had at the source -- `/80971/2024-wec-2-cadillac-droite.png` --
and the six characters that id occupies are what is dropped.

The event page calls this now, for the car the middle of the page is given over
to and for every card of the standings, so all three per-season tables are in
the bundle -- 11 kB for the field's photographs.

-}
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
                |> Maybe.map (\fileName -> String.concat [ "/static/images/wec/2024", String.dropLeft 6 fileName ])

        2025 ->
            carImageFileName_2025 carNumber
                |> Maybe.map (\fileName -> String.concat [ "/static/images/wec/2025", String.dropLeft 6 fileName ])

        2026 ->
            carImageFileName_2026 carNumber
                |> Maybe.map (\fileName -> String.concat [ "/static/images/wec/2026", String.dropLeft 6 fileName ])

        _ ->
            Nothing
