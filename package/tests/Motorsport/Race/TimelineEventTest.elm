module Motorsport.Race.TimelineEventTest exposing (suite)

import Expect
import Json.Decode as Decode
import Motorsport.Class as Class
import Motorsport.Driver exposing (Driver)
import Motorsport.Duration as Duration
import Motorsport.Flag exposing (Flag(..))
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.MiniSector as MiniSector
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (CarEventType(..), EventType(..))
import Motorsport.TestHelpers.Driver exposing (driverNamed)
import Motorsport.TestHelpers.Lap as TestLap
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "TimelineEvent"
        [ decoder
        , lapDetail
        , carEventLaps
        , handover
        ]


decoder : Test
decoder =
    describe "TimelineEvent.decoder"
        [ test "the race's own start is nobody's" <|
            \_ ->
                decoded """{ "elapsed": "0.000", "event": "raceStart" }"""
                    |> Expect.equal (Ok ( Instant.raceStart, RaceStart ))
        , test "every other event names the car it was" <|
            \_ ->
                decoded """{ "elapsed": "0.000", "event": "overtakeForLead", "carNumber": "7" }"""
                    |> Expect.equal (Ok ( Instant.raceStart, CarEvent "7" OvertakeForLead ))
        , test "each of the kinds reads back as itself" <|
            \_ ->
                [ "overtakeForLead", "leaderInPit", "fastestLap", "driverChange", "retired", "finished" ]
                    |> List.map (written >> Result.map Tuple.second)
                    |> Expect.equal
                        [ Ok (CarEvent "7" OvertakeForLead)
                        , Ok (CarEvent "7" LeaderInPit)
                        , Ok (CarEvent "7" FastestLap)
                        , Ok (CarEvent "7" DriverChange)
                        , Ok (CarEvent "7" Retired)
                        , Ok (CarEvent "7" Finished)
                        ]
        , test "a flag is nobody's, and reads back as itself" <|
            \_ ->
                [ "fullCourseYellow", "safetyCar", "redFlag", "greenFlag" ]
                    |> List.map (\name -> decoded ("{ \"elapsed\": \"1:00.000\", \"event\": \"" ++ name ++ "\" }") |> Result.map Tuple.second)
                    |> Expect.equal
                        [ Ok (Flag FullCourseYellow)
                        , Ok (Flag SafetyCar)
                        , Ok (Flag RedFlag)
                        , Ok (Flag GreenFlag)
                        ]
        , test "a kind this app has no case for fails the round" <|
            \_ ->
                -- Carried on from, a car's event of a kind this app cannot read
                -- would read as a car that never stopped running.
                decoded """{ "elapsed": "0.000", "event": "slowZone" }"""
                    |> Expect.err
        , test "a name this timeline no longer writes fails the round" <|
            \_ ->
                [ "start", "tookLead", "retirement", "checkered" ]
                    |> List.map (written >> Result.toMaybe)
                    |> Expect.equal [ Nothing, Nothing, Nothing, Nothing ]
        ]


{-| An event of one name, of car 7, at nought.
-}
written : String -> Result Decode.Error ( Instant, EventType )
written name =
    decoded ("{ \"elapsed\": \"0.000\", \"event\": \"" ++ name ++ "\", \"carNumber\": \"7\" }")


{-| `(when, what)`, which is the whole of an event.
-}
decoded : String -> Result Decode.Error ( Instant, EventType )
decoded json =
    Decode.decodeString TimelineEvent.decoder json
        |> Result.map (\event -> ( event.elapsed, event.eventType ))


{-| The lap an event fell on is written flat beside it, and these are the lines
`Round.Render` writes -- the key names are the seam between the two, and nothing but
a test reads one against the other.
-}
lapDetail : Test
lapDetail =
    describe "TimelineEvent.decoder, of the lap an event fell on"
        [ test "an event on nobody's lap carries no detail" <|
            \_ ->
                Decode.decodeString TimelineEvent.decoder """{ "elapsed": "0.000", "event": "raceStart" }"""
                    |> Result.map .lap
                    |> Expect.equal (Ok Nothing)
        , test "the lap a fastest lap was set on comes back in full" <|
            \_ ->
                Decode.decodeString TimelineEvent.decoder cotaFastestLap
                    |> Result.map .lap
                    |> Expect.equal
                        (Ok
                            (Just
                                { driver = driverNamed "Philip HANSON"
                                , lap = rated "3:08.310" "3:08.310" "3:08.310"
                                , sectors =
                                    { s1 = rated "40.152" "40.152" "40.152"
                                    , s2 = rated "1:12.811" "1:12.811" "1:12.811"
                                    , s3 = rated "1:15.347" "1:09.182" "1:13.095"
                                    }
                                , miniSectors = Nothing
                                }
                            )
                        )
        , test "a circuit the tracker has no lines for carries no mini-sectors" <|
            \_ ->
                Decode.decodeString TimelineEvent.decoder cotaFastestLap
                    |> Result.map (.lap >> Maybe.map .miniSectors)
                    |> Expect.equal (Ok (Just Nothing))
        , test "Le Mans's fifteen read back by their own names" <|
            \_ ->
                case Decode.decodeString TimelineEvent.decoder leMansFastestLap of
                    Err problem ->
                        Expect.fail (Decode.errorToString problem)

                    Ok event ->
                        case Maybe.andThen .miniSectors event.lap of
                            Nothing ->
                                Expect.fail "the line carries no mini-sectors"

                            Just mini ->
                                Expect.equal
                                    (MiniSector.get "SCL2" mini
                                        |> Maybe.map (\r -> ( r.time, r.fastest, r.personalBest ))
                                    )
                                    (Just
                                        ( Duration.fromString "8.151"
                                        , Duration.fromString "8.151"
                                        , Duration.fromString "8.151"
                                        )
                                    )
        , test "a lap named with nothing beside it fails the round" <|
            \_ ->
                Decode.decodeString TimelineEvent.decoder
                    """{ "elapsed": "6:27.414", "event": "fastestLap", "carNumber": "83", "lap": 2 }"""
                    |> Expect.err
        ]


{-| Every car event names the lap it fell on, and only a fastest lap carries that lap's
times. These are lines the kept round actually writes, so a decoder that reads a
`lap` on its own as a promise of `performance` fails here rather than taking the
whole events column down with it.
-}
carEventLaps : Test
carEventLaps =
    let
        namesItsLap line =
            case Decode.decodeString TimelineEvent.decoder line of
                Err problem ->
                    Err (Decode.errorToString problem)

                Ok event ->
                    if event.lapNumber == Nothing || event.lap /= Nothing then
                        Err ("expected a lap and no detail, got " ++ Debug.toString event)

                    else
                        Ok ()
    in
    describe "TimelineEvent.decoder, of the lap every car event names"
        [ test "a car event names its lap and carries no detail" <|
            \_ ->
                List.foldl
                    (\line seen ->
                        Result.andThen (\_ -> namesItsLap line) seen
                    )
                    (Ok ())
                    [ driverChange
                    , overtakeForLead
                    , leaderInPit
                    , finished
                    , retired
                    ]
                    |> Expect.ok
        , test "the number reaches the stamp, and no detail reaches the strip" <|
            \_ ->
                Decode.decodeString TimelineEvent.decoder driverChange
                    |> Result.map (\event -> ( event.eventType, event.lapNumber, event.lap ))
                    |> Expect.equal
                        (Ok
                            ( CarEvent "87" DriverChange
                            , Just 4
                            , Nothing
                            )
                        )
        ]


driverChange : String
driverChange =
    """{ "elapsed": "13:16.461", "event": "driverChange", "carNumber": "87", "lap": 4 }"""


overtakeForLead : String
overtakeForLead =
    """{ "elapsed": "1:43:58.268", "event": "overtakeForLead", "carNumber": "83", "lap": 20 }"""


leaderInPit : String
leaderInPit =
    """{ "elapsed": "33:55.160", "event": "leaderInPit", "carNumber": "88", "lap": 11 }"""


finished : String
finished =
    """{ "elapsed": "6:01:25.310", "event": "finished", "carNumber": "6", "lap": 120 }"""


retired : String
retired =
    """{ "elapsed": "39:37.017", "event": "retired", "carNumber": "20", "lap": 13 }"""


rated : String -> String -> String -> TimelineEvent.Rated
rated time fastest personalBest =
    { time = Duration.fromString time
    , fastest = Duration.fromString fastest
    , personalBest = Duration.fromString personalBest
    }


cotaFastestLap : String
cotaFastestLap =
    """{ "elapsed": "6:27.414", "event": "fastestLap", "carNumber": "83", "lap": 2, "driver": "Philip HANSON", "performance": { "lap": { "time": "3:08.310", "fastest": "3:08.310", "personalBest": "3:08.310" }, "sectors": { "s1": { "time": "40.152", "fastest": "40.152", "personalBest": "40.152" }, "s2": { "time": "1:12.811", "fastest": "1:12.811", "personalBest": "1:12.811" }, "s3": { "time": "1:15.347", "fastest": "1:09.182", "personalBest": "1:13.095" } } } }"""


{-| Le Mans's fifteen mini-sectors, on the lap car 5 set its fastest at 7:11.321.
-}
leMansFastestLap : String
leMansFastestLap =
    """{ "elapsed": "7:11.321", "event": "fastestLap", "carNumber": "5", "lap": 2, "driver": "Julien ANDLAUER", "performance": { "lap": { "time": "3:28.312", "fastest": "3:28.312", "personalBest": "3:28.312" }, "sectors": { "s1": { "time": "32.944", "fastest": "32.944", "personalBest": "32.944" }, "s2": { "time": "1:19.882", "fastest": "1:19.882", "personalBest": "1:19.882" }, "s3": { "time": "1:35.486", "fastest": "1:35.486", "personalBest": "1:35.486" } }, "miniSectors": [{"name":"SCL2","time":"8.151","fastest":"8.151","personalBest":"8.151"},{"name":"Z4","time":"10.176","fastest":"10.176","personalBest":"10.176"},{"name":"IP1","time":"14.617","fastest":"14.617","personalBest":"14.617"},{"name":"Z12","time":"32.700","fastest":"32.700","personalBest":"32.700"},{"name":"SCLC","time":"4.770","fastest":"4.629","personalBest":"4.762"},{"name":"A7-1","time":"25.436","fastest":"25.436","personalBest":"25.436"},{"name":"IP2","time":"16.976","fastest":"16.919","personalBest":"16.976"},{"name":"A8-1","time":"6.535","fastest":"6.535","personalBest":"6.535"},{"name":"SCLB","time":"36.619","fastest":"36.619","personalBest":"36.619"},{"name":"PORIN","time":"16.821","fastest":"16.708","personalBest":"16.821"},{"name":"POROUT","time":"15.298","fastest":"15.298","personalBest":"15.298"},{"name":"PITREF","time":"7.822","fastest":"7.796","personalBest":"7.817"},{"name":"SCL1","time":"2.597","fastest":"2.597","personalBest":"2.597"},{"name":"FORDOUT","time":"6.249","fastest":"6.189","personalBest":"6.249"},{"name":"FL","time":"3.545","fastest":"3.437","personalBest":"3.503"}] } }"""


{-| The handover reads the laps either side of the event, so these are the two
lap boundaries an event can fall between.
-}
handover : Test
handover =
    describe "TimelineEvent.handover"
        [ test "the pair the event falls between" <|
            \_ ->
                TimelineEvent.handover (car [ lapOf 1 kobayashi 60000, lapOf 2 conway 120000 ]) (changeAt 90000)
                    |> Expect.equal (Just ( kobayashi, conway ))
        , test "a three-driver car hands over twice, and each event reads its own pair" <|
            \_ ->
                let
                    theCar =
                        car [ lapOf 1 kobayashi 60000, lapOf 2 conway 120000, lapOf 3 buemi 180000 ]
                in
                [ changeAt 90000, changeAt 150000 ]
                    |> List.map (TimelineEvent.handover theCar)
                    |> Expect.equal [ Just ( kobayashi, conway ), Just ( conway, buemi ) ]
        , test "an event before the car's first lap names nobody" <|
            \_ ->
                TimelineEvent.handover (car [ lapOf 1 kobayashi 60000, lapOf 2 conway 120000 ]) (changeAt 30000)
                    |> Expect.equal Nothing
        , test "no handover where the laps either side name one driver" <|
            \_ ->
                TimelineEvent.handover (car [ lapOf 1 kobayashi 60000, lapOf 2 kobayashi 120000 ]) (changeAt 90000)
                    |> Expect.equal Nothing
        , test "an event after the car's last lap names nobody" <|
            \_ ->
                TimelineEvent.handover (car [ lapOf 1 kobayashi 60000, lapOf 2 conway 120000 ]) (changeAt 300000)
                    |> Expect.equal Nothing
        ]


kobayashi : Driver
kobayashi =
    driverNamed "Kamui KOBAYASHI"


conway : Driver
conway =
    driverNamed "Mike CONWAY"


buemi : Driver
buemi =
    driverNamed "Sebastian BUEMI"


lapOf : Int -> Driver -> Int -> Lap
lapOf lapNumber driver elapsed =
    let
        base =
            TestLap.empty
    in
    { base | lap = lapNumber, driver = driver, elapsed = Instant.fromDuration elapsed }


changeAt : Int -> TimelineEvent.TimelineEvent
changeAt ms =
    { elapsed = Instant.fromDuration ms
    , eventType = CarEvent "7" DriverChange
    , lapNumber = Nothing
    , lap = Nothing
    }


car : List Lap -> Car
car laps =
    { metadata =
        { carNumber = "7"
        , drivers = []
        , class = Class.none
        , group = "H"
        , team = "Toyota Racing"
        , manufacturer = Manufacturer.unknown
        , imageUrl = Nothing
        }
    , startPosition = 1
    , laps = laps
    }
