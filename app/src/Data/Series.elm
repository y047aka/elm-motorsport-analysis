module Data.Series exposing (carImageUrl_Wec, toEventSummary)

import Data.Series.EventSummary exposing (EventSummary)
import Data.Series.Wec as Wec exposing (Wec)
import Data.Series.Wec_2024 exposing (carImageFileName_2024, wec_2024)
import Data.Series.Wec_2025 exposing (carImageFileName_2025, wec_2025)
import Data.Series.Wec_2026 exposing (carImageFileName_2026, wec_2026)
import List.Extra
import Motorsport.Wec.Era as Era


{-| The event, if the app can show it: it has to be one the season actually ran,
in a season with an era to read its classes against.

A round the calendar did not hold -- there was no Qatar race in 2024 -- is as
absent as a season nobody has data for. Both resolve to `Nothing` rather than to
an event with a date and a path to a file that was never there.

-}
toEventSummary : ( Int, Wec ) -> Maybe EventSummary
toEventSummary ( season, event ) =
    Era.fromSeason season
        |> Maybe.andThen (\_ -> calendar season)
        |> Maybe.andThen (List.Extra.find (\summary -> summary.id == Wec.toString event))


{-| The rounds a season actually ran -- the same list the index page offers.
-}
calendar : Int -> Maybe (List EventSummary)
calendar season =
    case season of
        2024 ->
            Just wec_2024

        2025 ->
            Just wec_2025

        2026 ->
            Just wec_2026

        _ ->
            Nothing


{-| Where the car's image is served from.

The images were taken from
`https://storage.googleapis.com/ecm-prod/media/cache/easy_thumb/assets/1/engage`
and now sit under `/static/images/wec/<season>`. Each name there still carries
the asset id it had at the source -- `/80971/2024-wec-2-cadillac-droite.png` --
and the six characters that id occupies are what is dropped.

Nothing calls this yet, so the compiler drops it and the three per-season image
tables with it. Worth keeping that way: reaching those tables from code that
does run -- by pairing them with the calendar in a single per-season lookup,
say -- pulls all three into the bundle, for 11 kB and a feature that is not
wired up.

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
