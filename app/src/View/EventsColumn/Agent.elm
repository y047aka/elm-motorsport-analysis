module View.EventsColumn.Agent exposing (surfaceId, messages)

{-| The events column's surface, said in A2UI messages: the side of the protocol a remote agent would speak, run here in the app over the round's own timeline.

The surface is the whole race at once. The clock is not the agent's: the catalog's `Feed` reveals its posts by their `elapsed`, so the messages are sent once per round and never again as the race runs.

Which events are posted, what each is called and which flag colours race control's avatar are decided here; how a post is laid out is the catalog's renderer's.

@docs surfaceId, messages

-}

import A2ui exposing (Message, Value(..))
import Array
import Dict exposing (Dict)
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration
import Motorsport.Flag exposing (Flag(..))
import Motorsport.Instant as Instant
import Motorsport.Lap.Performance as Performance exposing (PerformanceLevel(..))
import Motorsport.MiniSector as MiniSector
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Motorsport.Sector as Sector
import View.EventsColumn.Catalog as Catalog


surfaceId : String
surfaceId =
    "events"


{-| The surface, its components, and the posts as its data model.

A post's key is the event's place in the timeline, so a post keeps its key however far the clock has run.

-}
messages : List Car -> Timeline -> List Message
messages cars timeline =
    let
        carsByNumber =
            List.foldr (\car -> Dict.insert car.metadata.carNumber car) Dict.empty cars
    in
    [ A2ui.CreateSurface { surfaceId = surfaceId, catalogId = Catalog.catalogId }
    , A2ui.UpdateComponents { surfaceId = surfaceId, components = components }
    , A2ui.UpdateDataModel
        { surfaceId = surfaceId
        , path = "/posts"
        , value =
            Timeline.toList timeline
                |> List.indexedMap (\id event -> post id event (named event carsByNumber))
                |> Array.fromList
                |> JArray
        }
    ]


components : List A2ui.Component
components =
    let
        bound path =
            object [ ( "@path", JString path ) ]

        component id name properties =
            { id = id, component = name, properties = Dict.fromList properties }
    in
    [ component "root"
        "Feed"
        [ ( "head", JString "Race Timeline" )
        , ( "empty", JString "Nothing has happened yet" )
        , ( "end", JString "You have reached the start of the race" )
        , ( "children", object [ ( "path", JString "/posts" ), ( "componentId", JString "post" ) ] )
        ]
    , component "post"
        "Post"
        [ ( "key", bound "key" )
        , ( "elapsed", bound "elapsed" )
        , ( "avatar", JString "post-avatar" )
        , ( "headline", JString "post-headline" )
        , ( "author", bound "author" )
        , ( "body", JString "post-body" )
        , ( "stamp", bound "stamp" )
        ]
    , component "post-avatar" "Avatar" [ ( "carNumber", bound "carNumber" ), ( "flag", bound "flag" ) ]
    , component "post-headline" "Headline" [ ( "carNumber", bound "carNumber" ) ]
    , component "post-body" "EventBody" [ ( "text", bound "text" ), ( "fastestLap", bound "fastestLap" ) ]
    ]


{-| Which car the event names. The field's own events -- a flag, the start -- name none, and are posted by race control.
-}
named : TimelineEvent -> Dict String Car -> Maybe Car
named event carsByNumber =
    case event.eventType of
        CarEvent carNumber _ ->
            Dict.get carNumber carsByNumber

        _ ->
            Nothing


post : Int -> TimelineEvent -> Maybe Car -> Value
post id event theCar =
    object
        ([ ( "key", JString (String.fromInt id) )
         , ( "elapsed", int (Instant.toDuration event.elapsed) )
         , ( "author", JString (Maybe.map (.metadata >> .team) theCar |> Maybe.withDefault "Race Control") )
         , ( "text", JString (text event theCar) )
         , ( "stamp", JString (stamp event) )
         ]
            ++ present "carNumber" (Maybe.map (.metadata >> .carNumber >> JString) theCar)
            ++ present "flag" (flagOf event.eventType)
            ++ present "fastestLap" (fastestLap event)
        )


{-| The flag race control's avatar wears, spelled as a timeline file spells it. Every other post's avatar wears none.
-}
flagOf : EventType -> Maybe Value
flagOf eventType =
    case eventType of
        Flag flag ->
            Just
                (JString
                    (case flag of
                        FullCourseYellow ->
                            "fullCourseYellow"

                        SafetyCar ->
                            "safetyCar"

                        RedFlag ->
                            "redFlag"

                        GreenFlag ->
                            "greenFlag"
                    )
                )

        _ ->
            Nothing


{-| What happened. A fastest lap is the class's, whether or not it is also the field's -- which is why the post says `Class Fastest Lap`.
-}
text : TimelineEvent -> Maybe Car -> String
text event theCar =
    case ( event.eventType, theCar ) of
        -- The one arm that reads the car, for the two names the handover is between.
        -- With no car row it says the generic line.
        ( CarEvent _ DriverChange, Just car ) ->
            TimelineEvent.handover car event
                |> Maybe.map (\( handedOver, tookOver ) -> Driver.handover handedOver tookOver)
                |> Maybe.withDefault (TimelineEvent.describe event.eventType)

        ( CarEvent _ FastestLap, _ ) ->
            "Class Fastest Lap"

        _ ->
            TimelineEvent.describe event.eventType


{-| The lap the backend attached to a fastest lap, with its segments rated against the records as they stood when it was set, not as they stand at the clock: a post two hours old would otherwise be recoloured by a sector beaten since.
-}
fastestLap : TimelineEvent -> Maybe Value
fastestLap event =
    case ( event.eventType, event.lap ) of
        ( CarEvent _ FastestLap, Just lap ) ->
            Just <|
                object
                    (( "driver", JString (Driver.initialsAndSurname lap.driver) )
                        :: present "time" (Maybe.map int lap.lap.time)
                        ++ (case lap.miniSectors of
                                Just miniSectors ->
                                    [ ( "miniSectors", segments (MiniSector.toList miniSectors) ) ]

                                Nothing ->
                                    [ ( "sectors"
                                      , segments
                                            (Sector.toList lap.sectors
                                                |> List.map (Tuple.mapFirst Sector.toString)
                                            )
                                      )
                                    ]
                           )
                    )

        _ ->
            Nothing


segments : List ( String, TimelineEvent.Rated ) -> Value
segments cells =
    cells
        |> List.map
            (\( name, rated ) ->
                let
                    rating =
                        Performance.rateTime rated.fastest
                            { time = rated.time, personalBest = rated.personalBest }
                in
                object
                    (( "name", JString name )
                        :: present "time" (Maybe.map (.time >> int) rating)
                        ++ present "rating" (Maybe.map (.performance >> level >> JString) rating)
                    )
            )
        |> Array.fromList
        |> JArray


level : PerformanceLevel -> String
level performance =
    case performance of
        Fastest ->
            "fastest"

        PersonalBest ->
            "personalBest"

        Standard ->
            "standard"


{-| The moment the event fell, and the lap it fell on -- one behind the lap a timing sheet has the car on, which is what the event's own line calls it.
-}
stamp : TimelineEvent -> String
stamp event =
    Duration.toStringToSeconds (Instant.toDuration event.elapsed)
        ++ (event.lapNumber
                |> Maybe.map (\lap -> " · Lap " ++ String.fromInt lap)
                |> Maybe.withDefault ""
           )


object : List ( String, Value ) -> Value
object =
    Dict.fromList >> JObject


int : Int -> Value
int =
    toFloat >> JNumber


present : String -> Maybe Value -> List ( String, Value )
present key =
    Maybe.map (\value -> [ ( key, value ) ]) >> Maybe.withDefault []
