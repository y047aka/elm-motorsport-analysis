module Data.Wec.CalendarTest exposing (suite)

import Data.Wec.Calendar as Calendar
import Expect
import Json.Decode as Decode
import Test exposing (Test, describe, test)


{-| Two seasons running the same round, which is the case the app cannot resolve
on the id alone. Shaped as `Motorsport.Calendar.toJson` writes it.
-}
json : String
json =
    """
    { "seasons":
        [ { "season": 2026
          , "rounds":
                [ { "id": "spa_6h", "name": "6 Hours of Spa", "date": "2026-05-09"
                  , "summary": "/static/wec/2026/spa_6h.json"
                  , "laps": "/static/wec/2026/spa_6h_laps.json"
                  }
                ]
          }
        , { "season": 2025
          , "rounds":
                [ { "id": "spa_6h", "name": "6 Hours of Spa", "date": "2025-05-10"
                  , "summary": "/static/wec/2025/spa_6h.json"
                  , "laps": "/static/wec/2025/spa_6h_laps.json"
                  }
                , { "id": "fuji_6h", "name": "6 Hours of Fuji", "date": "2025-09-28"
                  , "summary": "/static/wec/2025/fuji_6h.json"
                  , "laps": "/static/wec/2025/fuji_6h_laps.json"
                  }
                ]
          }
        ]
    }
    """


decoded : Calendar.Calendar
decoded =
    Decode.decodeString Calendar.decoder json
        |> Result.withDefault Calendar.empty


suite : Test
suite =
    describe "Data.Wec.Calendar"
        [ describe "decoder"
            [ test "keeps the seasons in the order the file lists them" <|
                \_ ->
                    -- The first season is the latest one, and that ordering is
                    -- the whole of what the index page reads to say so.
                    decoded
                        |> List.map .season
                        |> Expect.equalLists [ 2026, 2025 ]
            , test "keeps each season's rounds in the order it ran them" <|
                \_ ->
                    decoded
                        |> List.concatMap (.rounds >> List.map .id)
                        |> Expect.equalLists [ "spa_6h", "spa_6h", "fuji_6h" ]
            , test "reads a round's paths rather than leaving them to be built" <|
                \_ ->
                    decoded
                        |> List.concatMap (.rounds >> List.map (\round -> ( round.summary, round.laps )))
                        |> List.take 1
                        |> Expect.equalLists
                            [ ( "/static/wec/2026/spa_6h.json"
                              , "/static/wec/2026/spa_6h_laps.json"
                              )
                            ]
            , test "fails rather than guessing when a round is missing its paths" <|
                \_ ->
                    -- A CLI that stopped writing them would otherwise leave the
                    -- app fetching the empty string.
                    """{ "seasons": [ { "season": 2025, "rounds": [ { "id": "spa_6h", "name": "6 Hours of Spa", "date": "2025-05-10" } ] } ] }"""
                        |> Decode.decodeString Calendar.decoder
                        |> Result.toMaybe
                        |> Expect.equal Nothing
            ]
        , describe "findRound"
            [ test "tells apart the same round in two different seasons" <|
                \_ ->
                    decoded
                        |> Calendar.findRound { season = "2025", event = "spa_6h" }
                        |> Maybe.map (\( season, round ) -> ( season.season, round.date ))
                        |> Expect.equal (Just ( 2025, "2025-05-10" ))
            , test "turns down anything the calendar does not list" <|
                \_ ->
                    -- A season that ran no such round, and a season with no
                    -- rounds at all.
                    [ { season = "2026", event = "fuji_6h" }
                    , { season = "2024", event = "spa_6h" }
                    ]
                        |> List.map (\params -> Calendar.findRound params decoded)
                        |> Expect.equalLists [ Nothing, Nothing ]
            , test "matches the season as the string the URL carried" <|
                \_ ->
                    decoded
                        |> Calendar.findRound { season = "02025", event = "spa_6h" }
                        |> Expect.equal Nothing
            ]
        ]
