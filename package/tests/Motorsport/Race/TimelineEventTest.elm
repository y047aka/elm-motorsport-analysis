module Motorsport.Race.TimelineEventTest exposing (suite)

import Expect
import Json.Decode as Decode
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Flag exposing (Flag(..))
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (CarEventType(..), EventType(..))
import Motorsport.Wec.Class as Class
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "TimelineEvent"
        [ decoder
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
    Driver.fromName "Kamui KOBAYASHI"


conway : Driver
conway =
    Driver.fromName "Mike CONWAY"


buemi : Driver
buemi =
    Driver.fromName "Sebastian BUEMI"


lapOf : Int -> Driver -> Int -> Lap
lapOf lapNumber driver elapsed =
    let
        base =
            Lap.empty
    in
    { base | lap = lapNumber, driver = driver, elapsed = Instant.fromDuration elapsed }


changeAt : Int -> TimelineEvent.TimelineEvent
changeAt ms =
    { elapsed = Instant.fromDuration ms, eventType = CarEvent "7" DriverChange }


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
