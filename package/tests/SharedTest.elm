module SharedTest exposing (suite)

{-| Drives `Shared.update` from the outside. A round's states are not exposed,
so how far one has got is read back through `Shared.race` and `Shared.roundId`
-- all a page can see of it either.
-}

import Data.Wec as Wec
import Data.Wec.Calendar as Calendar
import Data.Wec.Laps as WecLaps
import Expect
import Json.Decode as Decode
import Motorsport.Replay as Replay
import Motorsport.Wec.Era as Era
import Shared
import Shared.Msg exposing (Msg(..))
import Test exposing (Test, describe, test)
import Time


{-| One season of two rounds: the pair a stale response can be mistaken for.
-}
calendarJson : String
calendarJson =
    """
    { "seasons":
        [ { "season": 2025
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


summaryJson : String
summaryJson =
    """
    { "name": "6 Hours of Spa"
    , "season": 2025
    , "date": "2025-05-10"
    , "race": { "duration": "6:00:00.000", "timeLimit": "6:00:00.000", "lapTotal": 2 }
    , "track":
        { "direction": "clockwise"
        , "sectors":
            { "s1": { "start": 0.0, "share": 0.3 }
            , "s2": { "start": 0.3, "share": 0.4 }
            , "s3": { "start": 0.7, "share": 0.3 }
            }
        }
    , "startingGrid":
        { "basis": "lap1_s1"
        , "entries":
            [ { "position": 1
              , "car":
                    { "carNumber": "7", "drivers": [ { "name": "KOBAYASHI" } ]
                    , "class": "HYPERCAR", "group": "H"
                    , "team": "Toyota Gazoo Racing", "manufacturer": "Toyota"
                    }
              }
            ]
        }
    }
    """


lapsJson : String
lapsJson =
    """
    [ { "car": { "carNumber": "7" }, "driverName": "KOBAYASHI"
      , "lapNumber": 1, "lap": { "time": "1:53.000", "improvement": 0 }
      , "sectors":
            { "s1": { "time": "30.000", "improvement": 0 }
            , "s2": { "time": "45.000", "improvement": 0 }
            , "s3": { "time": "38.000", "improvement": 0 }
            }
      , "elapsed": "1:53.000", "pitTime": ""
      }
    ]
    """


summary : Maybe Wec.Event
summary =
    Era.fromSeason 2025
        |> Maybe.andThen
            (\era ->
                Decode.decodeString (Wec.eventDecoder era) summaryJson
                    |> Result.toMaybe
            )


laps : List WecLaps.RawLap
laps =
    Decode.decodeString WecLaps.decoder lapsJson
        |> Result.withDefault []


{-| A fixture that failed to decode leaves the round unchanged rather than
passing an assertion by accident. The fixture test below is what says so.
-}
deliverSummary : { season : Int, id : String } -> Shared.Model -> Shared.Model
deliverSummary key model =
    case summary of
        Just decoded ->
            step (JsonLoaded_Wec key (Ok decoded)) model

        Nothing ->
            model


deliverLaps : { season : Int, id : String } -> Shared.Model -> Shared.Model
deliverLaps key model =
    step (LapsLoaded_Wec key (Ok laps)) model


spa : { season : Int, id : String }
spa =
    { season = 2025, id = "spa_6h" }


fuji : { season : Int, id : String }
fuji =
    { season = 2025, id = "fuji_6h" }


calendar : Calendar.Calendar
calendar =
    Decode.decodeString Calendar.decoder calendarJson
        |> Result.withDefault Calendar.empty


fresh : Shared.Model
fresh =
    Shared.init () |> Tuple.first


{-| Reached the way a link from the index page reaches it: the calendar was
already in when the URL arrived.
-}
loadingSpa : Shared.Model
loadingSpa =
    fresh
        |> step (CalendarLoaded (Ok calendar))
        |> step (FetchJson_Wec { season = "2025", event = "spa_6h" })


{-| The same round the other way round, which is what a deep link does: the URL
is known before the calendar that says where its files are.
-}
loadingSpaByDeepLink : Shared.Model
loadingSpaByDeepLink =
    fresh
        |> step (FetchJson_Wec { season = "2025", event = "spa_6h" })
        |> step (CalendarLoaded (Ok calendar))


step : Msg -> Shared.Model -> Shared.Model
step msg model =
    Shared.update msg model |> Tuple.first


suite : Test
suite =
    describe "Shared"
        [ test "the fixtures decode" <|
            \_ ->
                ( summary /= Nothing, List.length laps )
                    |> Expect.equal ( True, 1 )
        , describe "update"
            [ test "resolves the round whichever of the URL and the calendar is second" <|
                \_ ->
                    [ loadingSpa, loadingSpaByDeepLink ]
                        |> List.map (Shared.roundId >> Maybe.map .name)
                        |> Expect.equalLists
                            [ Just "6 Hours of Spa", Just "6 Hours of Spa" ]
            , test "loads a round reached by a deep link" <|
                \_ ->
                    loadingSpaByDeepLink
                        |> deliverSummary spa
                        |> deliverLaps spa
                        |> Shared.race
                        |> Expect.notEqual Nothing
            , test "leaves a round the calendar does not list unresolved" <|
                \_ ->
                    fresh
                        |> step (CalendarLoaded (Ok calendar))
                        |> step (FetchJson_Wec { season = "2025", event = "monza_6h" })
                        |> (\m -> ( Shared.roundId m, Shared.race m ))
                        |> Expect.equal ( Nothing, Nothing )
            , test "shows no race until both of the round's files are in" <|
                \_ ->
                    loadingSpa
                        |> deliverSummary spa
                        |> Shared.race
                        |> Expect.equal Nothing
            , test "builds the race once both are in, whichever order they arrive" <|
                \_ ->
                    [ loadingSpa |> deliverSummary spa |> deliverLaps spa
                    , loadingSpa |> deliverLaps spa |> deliverSummary spa
                    ]
                        |> List.map (Shared.race >> (/=) Nothing)
                        |> Expect.equalLists [ True, True ]
            , test "drops a file left over from a round already navigated away from" <|
                \_ ->
                    -- Untagged, Fuji's laps would land beside Spa's summary
                    -- and be assembled into a race that never ran.
                    loadingSpa
                        |> deliverSummary spa
                        |> deliverLaps fuji
                        |> Shared.race
                        |> Expect.equal Nothing
            , test "reports playback running only once a race is loaded and started" <|
                \_ ->
                    let
                        loaded =
                            loadingSpa |> deliverSummary spa |> deliverLaps spa
                    in
                    [ Shared.isPlaying loadingSpa
                    , Shared.isPlaying loaded
                    , Shared.isPlaying (loaded |> step (ReplayMsg (Replay.Start (Time.millisToPosix 0))))
                    ]
                        |> Expect.equalLists [ False, False, True ]
            , test "a stale pair does not complete the round that is waiting" <|
                \_ ->
                    -- Both files of the round left behind, arriving together.
                    loadingSpa
                        |> deliverLaps fuji
                        |> deliverSummary fuji
                        |> (\m -> ( Shared.roundId m |> Maybe.map .id, Shared.race m /= Nothing ))
                        |> Expect.equal ( Just "spa_6h", False )
            ]
        ]
