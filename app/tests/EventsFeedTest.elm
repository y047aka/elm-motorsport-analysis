module EventsFeedTest exposing (suite)

import A2ui exposing (Message(..), Value(..))
import Array
import Dict
import EventsFeed
import EventsFeed.Catalog as Catalog exposing (Avatar(..), Segments(..))
import Expect
import Motorsport.Class as Class
import Motorsport.Driver as Driver exposing (Driver)
import Motorsport.Flag as Flag exposing (Flag(..))
import Motorsport.Instant as Instant
import Motorsport.Lap as Lap exposing (Lap)
import Motorsport.Lap.Performance exposing (PerformanceLevel(..))
import Motorsport.Manufacturer as Manufacturer
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent as TimelineEvent
import Motorsport.Sector as Sector
import PersonName.Parse exposing (fromUppercasedSurname)
import Test exposing (Test, describe, test)


{-| Lines of the kept COTA timeline, so the surface is said over what the round itself serves.
-}
cota : Timeline
cota =
    [ """{ "elapsed": "0.000", "event": "raceStart" }"""
    , """{ "elapsed": "3:19.104", "event": "safetyCar" }"""
    , """{ "elapsed": "6:27.414", "event": "fastestLap", "carNumber": "83", "lap": 2, "driver": "Philip HANSON", "performance": { "lap": { "time": "3:08.310", "fastest": "3:08.310", "personalBest": "3:08.310" }, "sectors": { "s1": { "time": "40.152", "fastest": "40.152", "personalBest": "40.152" }, "s2": { "time": "1:12.811", "fastest": "1:12.811", "personalBest": "1:12.811" }, "s3": { "time": "1:15.347", "fastest": "1:09.182", "personalBest": "1:13.095" } } } }"""
    , """{ "elapsed": "1:00:20.613", "event": "redFlag" }"""
    ]
        |> String.join "\n"
        |> TimelineEvent.fromJsonl
        |> Result.withDefault []
        |> Timeline.fromList


suite : Test
suite =
    describe "EventsFeed"
        [ surface
        , withTheCar
        , spellings
        , refusals
        ]


surface : Test
surface =
    let
        feed =
            EventsFeed.surfaceOf [] cota
    in
    describe "the agent's surface, read back by the catalog"
        [ test "one post per event, keyed by its place in the timeline" <|
            \_ ->
                feed
                    |> Result.map (.posts >> Array.toList >> List.map .key)
                    |> Expect.equal (Ok [ "0", "1", "2", "3" ])
        , test "race control wears the flag it shows" <|
            \_ ->
                feed
                    |> Result.map (.posts >> Array.toList >> List.map .avatar)
                    |> Expect.equal
                        (Ok
                            [ RaceControlAvatar Nothing
                            , RaceControlAvatar (Just SafetyCar)
                            , RaceControlAvatar Nothing
                            , RaceControlAvatar (Just RedFlag)
                            ]
                        )
        , test "a car the field has no row for is posted by race control" <|
            \_ ->
                feed
                    |> Result.map (.posts >> Array.get 2 >> Maybe.map (\p -> ( p.author, p.headline )))
                    |> Expect.equal (Ok (Just ( "Race Control", Nothing )))
        , test "the fastest lap keeps its segments as they were rated when it was set" <|
            \_ ->
                feed
                    |> Result.map
                        (.posts
                            >> Array.get 2
                            >> Maybe.andThen (.body >> .fastestLap)
                            >> Maybe.map
                                (\lap ->
                                    ( lap.time
                                    , case lap.segments of
                                        BySectors sectors ->
                                            List.map (Maybe.map .performance) (Sector.values sectors)

                                        ByMiniSectors _ ->
                                            []
                                    )
                                )
                        )
                    |> Expect.equal (Ok (Just ( Just 188310, [ Just Fastest, Just Fastest, Just Standard ] )))
        , test "the stamp is the moment and the lap" <|
            \_ ->
                feed
                    |> Result.map (.posts >> Array.get 2 >> Maybe.map .stamp)
                    |> Expect.equal (Ok (Just "6:27 · Lap 2"))
        , test "the clock reveals the posts at or before it" <|
            \_ ->
                feed
                    |> Result.map
                        (\f ->
                            List.map (\ms -> Catalog.countUpTo (Instant.fromDuration ms) f)
                                [ 0, 199103, 199104, 387414, 3620613 ]
                        )
                    |> Expect.equal (Ok [ 1, 1, 2, 3, 4 ])
        ]


driverNamed : String -> Driver
driverNamed name =
    case fromUppercasedSurname name of
        Just person ->
            Driver.fromName person

        Nothing ->
            Debug.todo ("no driver named " ++ name)


lapOf : Int -> Driver -> Int -> Lap
lapOf lapNumber driver elapsed =
    { carNumber = "7"
    , driver = driver
    , lap = lapNumber
    , position = Nothing
    , time = Nothing
    , sectors = Sector.initialize (always { time = Nothing, personalBest = Nothing })
    , best = Nothing
    , elapsed = Instant.fromDuration elapsed
    , crossing = Lap.NoCrossing
    , flag = Lap.Green
    , miniSectors = Nothing
    }


{-| Car 7, handed from one driver to the other between its first lap and its second.
-}
car7 : Car
car7 =
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
    , laps = [ lapOf 1 (driverNamed "Kamui KOBAYASHI") 60000, lapOf 2 (driverNamed "Mike CONWAY") 120000 ]
    }


{-| Car 7's driver change, and a fastest lap of its whose second sector is the car's own best and not the field's.
-}
car7Timeline : Timeline
car7Timeline =
    [ """{ "elapsed": "1:30.000", "event": "driverChange", "carNumber": "7", "lap": 1 }"""
    , """{ "elapsed": "2:00.000", "event": "fastestLap", "carNumber": "7", "lap": 2, "driver": "Mike CONWAY", "performance": { "lap": { "time": "2:00.000", "fastest": "2:00.000", "personalBest": "2:00.000" }, "sectors": { "s1": { "time": "40.000", "fastest": "40.000", "personalBest": "40.000" }, "s2": { "time": "40.000", "fastest": "39.000", "personalBest": "40.000" }, "s3": { "time": "40.000", "fastest": "39.000", "personalBest": "39.500" } } } }"""
    ]
        |> String.join "\n"
        |> TimelineEvent.fromJsonl
        |> Result.withDefault []
        |> Timeline.fromList


withTheCar : Test
withTheCar =
    let
        feed =
            EventsFeed.surfaceOf [ car7 ] car7Timeline

        first =
            feed |> Result.map (.posts >> Array.get 0)
    in
    describe "a car the field has a row for"
        [ test "is named by its number, and posted by its team" <|
            \_ ->
                first
                    |> Result.map (Maybe.map (\p -> ( p.avatar, p.headline, p.author )))
                    |> Expect.equal (Ok (Just ( CarAvatar "7", Just "7", "Toyota Racing" )))
        , test "a driver change names the two drivers off the car's laps" <|
            \_ ->
                first
                    |> Result.map (Maybe.map (.body >> .text))
                    |> Expect.equal (Ok (Just "K.KOBAYASHI → M.CONWAY"))
        , test "a segment that is the car's own best and not the field's reads as a personal best" <|
            \_ ->
                feed
                    |> Result.map
                        (.posts
                            >> Array.get 1
                            >> Maybe.andThen (.body >> .fastestLap)
                            >> Maybe.map
                                (\lap ->
                                    case lap.segments of
                                        BySectors sectors ->
                                            List.map (Maybe.map .performance) (Sector.values sectors)

                                        ByMiniSectors _ ->
                                            []
                                )
                        )
                    |> Expect.equal (Ok (Just [ Just Fastest, Just PersonalBest, Just Standard ]))
        ]


spellings : Test
spellings =
    test "every flag the catalog spells, the timeline file's reading takes back" <|
        \_ ->
            [ FullCourseYellow, SafetyCar, RedFlag, GreenFlag ]
                |> List.map (Catalog.flagName >> Flag.fromString)
                |> Expect.equal (List.map Just [ FullCourseYellow, SafetyCar, RedFlag, GreenFlag ])


{-| A hand-built surface of two posts at `first` and `second` race milliseconds.
-}
twoPosts : String -> Int -> Int -> Result String Catalog.Feed
twoPosts catalogId first second =
    let
        component id name properties =
            { id = id, component = name, properties = Dict.fromList properties }

        bound path =
            JObject (Dict.singleton "@path" (JString path))

        item key elapsed =
            JObject (Dict.fromList [ ( "key", JString key ), ( "elapsed", JNumber (toFloat elapsed) ), ( "text", JString "x" ) ])
    in
    [ CreateSurface { surfaceId = "events", catalogId = catalogId, components = [], dataModel = Nothing }
    , UpdateComponents
        { surfaceId = "events"
        , components =
            [ component "root"
                "Feed"
                [ ( "head", JString "h" )
                , ( "empty", JString "e" )
                , ( "end", JString "n" )
                , ( "children", JObject (Dict.fromList [ ( "path", JString "/posts" ), ( "componentId", JString "post" ) ]) )
                ]
            , component "post"
                "Post"
                [ ( "key", bound "key" )
                , ( "elapsed", bound "elapsed" )
                , ( "avatar", JString "a" )
                , ( "headline", JString "h" )
                , ( "author", JString "RC" )
                , ( "body", JString "b" )
                , ( "stamp", JString "" )
                ]
            , component "a" "Avatar" []
            , component "h" "Headline" []
            , component "b" "EventBody" [ ( "text", bound "text" ) ]
            ]
        }
    , UpdateDataModel { surfaceId = "events", path = "/posts", value = JArray (Array.fromList [ item "0" first, item "1" second ]) }
    ]
        |> A2ui.surface "events"
        |> Result.andThen Catalog.fromSurface


refusals : Test
refusals =
    describe "what the catalog refuses"
        [ test "a hand-built surface in order reads" <|
            \_ ->
                twoPosts Catalog.catalogId 1 2
                    |> Result.map (.posts >> Array.length)
                    |> Expect.equal (Ok 2)
        , test "posts out of the clock's order" <|
            \_ ->
                twoPosts Catalog.catalogId 2 1
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "another catalog's surface" <|
            \_ ->
                twoPosts "urn:another" 1 2
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        ]
