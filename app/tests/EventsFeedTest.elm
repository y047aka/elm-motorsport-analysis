module EventsFeedTest exposing (suite)

import A2ui exposing (Message(..), Value(..))
import Array
import Dict
import EventsFeed
import EventsFeed.Catalog as Catalog exposing (Avatar(..), Segments(..))
import Expect
import Motorsport.Flag exposing (Flag(..))
import Motorsport.Instant as Instant
import Motorsport.Lap.Performance exposing (PerformanceLevel(..))
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent as TimelineEvent
import Motorsport.Sector as Sector
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
