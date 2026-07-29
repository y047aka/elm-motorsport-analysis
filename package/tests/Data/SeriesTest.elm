module Data.SeriesTest exposing (tests)

import Data.Series as Series
import Data.Series.Wec exposing (Wec(..))
import Data.Series.Wec_2024 exposing (wec_2024)
import Expect
import Test exposing (..)


tests : Test
tests =
    describe "Data.Series"
        [ describe "toEventSummary"
            [ test "resolves every round a season ran" <|
                \_ ->
                    wec_2024
                        |> List.map
                            (\summary ->
                                Data.Series.Wec.fromString summary.id
                                    |> Maybe.andThen (\event -> Series.toEventSummary ( 2024, event ))
                            )
                        |> Expect.equalLists (List.map Just wec_2024)
            , test "turns down a round the season did not hold" <|
                \_ ->
                    -- Qatar opened 2025 and 2026, but 2024's data starts at
                    -- Le Mans. Answering here would hand back an event whose
                    -- json was never there.
                    Series.toEventSummary ( 2024, Qatar_1812km )
                        |> Expect.equal Nothing
            , test "turns down a season the app has no data for" <|
                \_ ->
                    [ 2020, 2023, 0 ]
                        |> List.map (\season -> Series.toEventSummary ( season, LeMans_24h ))
                        |> Expect.equalLists [ Nothing, Nothing, Nothing ]
            , test "keeps each season's rounds to that season" <|
                \_ ->
                    -- Spa ran in 2025 and 2026 but not in 2024's data.
                    [ 2024, 2025, 2026 ]
                        |> List.map
                            (\season ->
                                Series.toEventSummary ( season, Spa_6h )
                                    |> Maybe.map .season
                            )
                        |> Expect.equalLists [ Nothing, Just 2025, Just 2026 ]
            ]
        ]
