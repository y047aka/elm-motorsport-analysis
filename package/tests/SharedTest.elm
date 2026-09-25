module SharedTest exposing (suite)

{-| Drives `Shared.update` from the outside. A round's states are not exposed,
so how far one has got is read back through `Shared.loadedRound` and `Shared.roundId`
-- all a page can see of it either.
-}

import Data.Wec as Wec
import Data.Wec.Calendar as Calendar
import Data.Wec.CarImage as CarImage
import Data.Wec.Laps as WecLaps
import Data.Wec.Manufacturer as Manufacturer
import Dict
import Expect
import Http
import Json.Decode as Decode
import Motorsport.Instant as Instant
import Motorsport.Race.Timeline as Timeline
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (TimelineEvent)
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
                  , "laps": "/static/wec/2025/spa_6h_laps.jsonl"
                  , "timeline": "/static/wec/2025/spa_6h_timeline.jsonl"
                  }
                , { "id": "fuji_6h", "name": "6 Hours of Fuji", "date": "2025-09-28"
                  , "summary": "/static/wec/2025/fuji_6h.json"
                  , "laps": "/static/wec/2025/fuji_6h_laps.jsonl"
                  , "timeline": "/static/wec/2025/fuji_6h_timeline.jsonl"
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
    , "index":
        { "lapCompletions": [ { "lap": 1, "elapsed": "1:53.000" } ]
        , "bestTimeChanges":
            { "fastestLapTime":
                [ { "elapsed": "1:53.000", "time": "1:53.000", "carNumber": "7", "lap": 1, "driver": "KOBAYASHI" } ]
            , "sectors": { "s1": [], "s2": [], "s3": [] }
            , "miniSectors":
                { "scl2": [], "z4": [], "ip1": [], "z12": [], "sclc": []
                , "a7_1": [], "ip2": [], "a8_1": [], "sclb": [], "porin": []
                , "porout": [], "pitref": [], "scl1": [], "fordout": [], "fl": []
                }
            }
        }
    }
    """


lapsJsonl : String
lapsJsonl =
    """{ "carNumber": "7", "lapNumber": 1, "position": 0, "driverName": "KOBAYASHI", "lap": { "time": "1:53.000", "improvement": 0 }, "sectors": { "s1": { "time": "30.000", "improvement": 0 }, "s2": { "time": "45.000", "improvement": 0 }, "s3": { "time": "38.000", "improvement": 0 } }, "elapsed": "1:53.000", "crossingFinishLineInPit": "", "pitTime": "" }
"""


{-| The timeline of that one lap: car 7 crossed the line once and never again,
which is a long way short of the six hours the round was scheduled for.
-}
timelineJsonl : String
timelineJsonl =
    """{ "elapsed": "0.000", "event": "raceStart" }
{ "elapsed": "1:53.000", "event": "retirement", "carNumber": "7" }
"""


manufacturersJson : String
manufacturersJson =
    """
    { "manufacturers":
        [ { "name": "Toyota"
          , "color": "oklch(0.6 0 0)"
          , "logo": "/assets/manufacturer-logos/toyota.png"
          }
        ]
    }
    """


carImagesJson : String
carImagesJson =
    """
    { "seasons":
        { "2025":
            { "basePath": "/static/images/wec/2025"
            , "cars":
                { "7":
                    { "default": "toyota-7.png"
                    , "rounds": { "le_mans_24h": "toyota-7-le-mans.png" }
                    }
                }
            }
        }
    }
    """


summary : Maybe Wec.Event
summary =
    eventAt "spa_6h"


eventAt : String -> Maybe Wec.Event
eventAt round =
    Era.fromSeason 2025
        |> Maybe.andThen
            (\era ->
                Decode.decodeString
                    (Wec.eventDecoder era manufacturers (photographAt round))
                    summaryJson
                    |> Result.toMaybe
            )


photographAt : String -> String -> Maybe String
photographAt round carNumber =
    CarImage.url carImages { season = 2025, round = round, carNumber = carNumber }


{-| The photograph the round's one car is given, which is the whole of what a
round changes about it.
-}
liveryAt : String -> Maybe String
liveryAt round =
    eventAt round
        |> Maybe.andThen (.startingGrid >> .entries >> List.head)
        |> Maybe.andThen (.car >> .imageUrl)


laps : List WecLaps.RawLap
laps =
    WecLaps.fromJsonl lapsJsonl
        |> Result.withDefault []


timeline : List TimelineEvent
timeline =
    TimelineEvent.fromJsonl timelineJsonl
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


deliverTimeline : { season : Int, id : String } -> Shared.Model -> Shared.Model
deliverTimeline key model =
    step (TimelineLoaded_Wec key (Ok timeline)) model


{-| How many events the round ended up holding, which is the whole of what the
timeline is to a page. A round that never loaded reads as -1 rather than as one
holding none.
-}
eventCount : Shared.Model -> Int
eventCount model =
    Shared.loadedRound model
        |> Maybe.map (.timeline >> Timeline.countUpTo (Instant.fromDuration 99999999))
        |> Maybe.withDefault -1


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


manufacturers : Manufacturer.Manufacturers
manufacturers =
    Decode.decodeString Manufacturer.decoder manufacturersJson
        |> Result.withDefault Dict.empty


carImages : CarImage.CarImages
carImages =
    Decode.decodeString CarImage.decoder carImagesJson
        |> Result.withDefault CarImage.none


fresh : Shared.Model
fresh =
    Shared.init () |> Tuple.first


{-| Reached the way a link from the index page reaches it: the calendar was
already in when the URL arrived.
-}
loadingSpa : Shared.Model
loadingSpa =
    fresh
        |> step (ManufacturersLoaded (Ok manufacturers))
        |> step (CarImagesLoaded (Ok carImages))
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
        |> step (ManufacturersLoaded (Ok manufacturers))
        |> step (CarImagesLoaded (Ok carImages))


step : Msg -> Shared.Model -> Shared.Model
step msg model =
    Shared.update msg model |> Tuple.first


suite : Test
suite =
    describe "Shared"
        [ test "the fixtures decode" <|
            \_ ->
                ( summary /= Nothing, List.length laps, List.length timeline )
                    |> Expect.equal ( True, 1, 2 )
        , test "puts on a car the livery it carried at the round being read" <|
            \_ ->
                ( liveryAt "spa_6h", liveryAt "le_mans_24h" )
                    |> Expect.equal
                        ( Just "/static/images/wec/2025/toyota-7.png"
                        , Just "/static/images/wec/2025/toyota-7-le-mans.png"
                        )
        , describe "update"
            [ test "resolves the round whichever of the URL, the calendar and the tables is last" <|
                \_ ->
                    [ loadingSpa, loadingSpaByDeepLink ]
                        |> List.map (Shared.roundId >> Maybe.map .name)
                        |> Expect.equalLists
                            [ Just "6 Hours of Spa", Just "6 Hours of Spa" ]
            , test "opens a round neither table reached" <|
                \_ ->
                    fresh
                        |> step (ManufacturersLoaded (Err Http.NetworkError))
                        |> step (CarImagesLoaded (Err Http.NetworkError))
                        |> step (CalendarLoaded (Ok calendar))
                        |> step (FetchJson_Wec { season = "2025", event = "spa_6h" })
                        |> Shared.roundId
                        |> Maybe.map .name
                        |> Expect.equal (Just "6 Hours of Spa")
            , test "loads a round reached by a deep link" <|
                \_ ->
                    loadingSpaByDeepLink
                        |> deliverSummary spa
                        |> deliverLaps spa
                        |> deliverTimeline spa
                        |> Shared.loadedRound
                        |> Expect.notEqual Nothing
            , test "leaves a round the calendar does not list unresolved" <|
                \_ ->
                    fresh
                        |> step (ManufacturersLoaded (Ok manufacturers))
                        |> step (CarImagesLoaded (Ok carImages))
                        |> step (CalendarLoaded (Ok calendar))
                        |> step (FetchJson_Wec { season = "2025", event = "monza_6h" })
                        |> (\m -> ( Shared.roundId m, Shared.loadedRound m ))
                        |> Expect.equal ( Nothing, Nothing )
            , test "shows no race until the summary and the laps are both in" <|
                \_ ->
                    [ loadingSpa |> deliverSummary spa
                    , loadingSpa |> deliverLaps spa
                    , loadingSpa |> deliverTimeline spa
                    , loadingSpa |> deliverSummary spa |> deliverTimeline spa
                    , loadingSpa |> deliverLaps spa |> deliverTimeline spa
                    ]
                        |> List.map (Shared.loadedRound >> (/=) Nothing)
                        |> Expect.equalLists [ False, False, False, False, False ]
            , test "builds the race off those two, whichever order they arrive" <|
                \_ ->
                    [ loadingSpa |> deliverSummary spa |> deliverLaps spa
                    , loadingSpa |> deliverLaps spa |> deliverSummary spa
                    , loadingSpa |> deliverTimeline spa |> deliverLaps spa |> deliverSummary spa
                    ]
                        |> List.map (Shared.loadedRound >> (/=) Nothing)
                        |> Expect.equalLists [ True, True, True ]
            , test "the timeline does not hold the round back, and lands on it either side of loading" <|
                \_ ->
                    [ loadingSpa |> deliverSummary spa |> deliverLaps spa
                    , loadingSpa |> deliverTimeline spa |> deliverSummary spa |> deliverLaps spa
                    , loadingSpa |> deliverSummary spa |> deliverLaps spa |> deliverTimeline spa
                    ]
                        |> List.map eventCount
                        |> Expect.equalLists [ 0, 2, 2 ]
            , test "a timeline that never arrives leaves the round rather than taking it away" <|
                \_ ->
                    loadingSpa
                        |> deliverSummary spa
                        |> deliverLaps spa
                        |> step (TimelineLoaded_Wec spa (Err Http.NetworkError))
                        |> Expect.all
                            [ Shared.loadedRound >> (/=) Nothing >> Expect.equal True
                            , eventCount >> Expect.equal 0
                            ]
            , test "drops a file left over from a round already navigated away from" <|
                \_ ->
                    -- Untagged, Fuji's laps would land beside Spa's summary
                    -- and be assembled into a race that never ran.
                    loadingSpa
                        |> deliverSummary spa
                        |> deliverTimeline spa
                        |> deliverLaps fuji
                        |> Shared.loadedRound
                        |> Expect.equal Nothing
            , test "reports playback running only once a race is loaded and started" <|
                \_ ->
                    let
                        loaded =
                            loadingSpa |> deliverSummary spa |> deliverLaps spa |> deliverTimeline spa
                    in
                    [ Shared.isPlaying loadingSpa
                    , Shared.isPlaying loaded
                    , Shared.isPlaying (loaded |> step (ReplayMsg (Replay.Start (Time.millisToPosix 0))))
                    ]
                        |> Expect.equalLists [ False, False, True ]
            , test "a stale set does not complete the round that is waiting" <|
                \_ ->
                    -- Every file of the round left behind, arriving together.
                    loadingSpa
                        |> deliverLaps fuji
                        |> deliverSummary fuji
                        |> deliverTimeline fuji
                        |> (\m -> ( Shared.roundId m |> Maybe.map .id, Shared.loadedRound m /= Nothing ))
                        |> Expect.equal ( Just "spa_6h", False )
            ]
        ]
