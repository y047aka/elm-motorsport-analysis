module View.EventsColumn exposing (Model, init, view)

{-| The round's events as a column of the strip: what has happened by the race
clock, newest first, one post per event.

The feed -- the frame, the posts, their paging -- is `View.Feed`. What is here is the
reading of a race's timeline into it: which events become posts, and what each of
them is called.

The visual tests locate the column by `data-events-column`.

-}

import Dict exposing (Dict)
import Html exposing (Html, div, span, text)
import Html.Attributes as Attributes exposing (attribute)
import Html.Lazy
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration
import Motorsport.Flag as Flag exposing (Flag(..))
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap.Performance as Performance
import Motorsport.Lap.SegmentStrip as SegmentStrip
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
import Motorsport.Sector as Sector exposing (Sector)
import Motorsport.Wec.Circuit.LeMans as LeMans
import View.CarNumberBadge as CarNumberBadge
import View.ClassMark as ClassMark
import View.Feed as Feed


type alias Model =
    Feed.Model


init : Model
init =
    Feed.init { perPage = 30 }


{-| The column, and the corner it is held and closed by.

The corner belongs to the strip rather than to the column: the same controls close
and carry every other column, and they answer to the page's own message.

-}
view :
    { corner : List (Html msg)
    , earlier : msg
    }
    -> Model
    -> List Car
    -> Timeline
    -> Instant
    -> Html msg
view controls model cars timeline clock =
    Feed.view
        { attributes = [ attribute "data-events-column" "" ]
        , corner = controls.corner
        , head = text "Race Timeline"
        , body =
            Html.Lazy.lazy5 (posts controls.earlier)
                model
                cars
                timeline
                (Timeline.countUpTo clock timeline)
                (clockStep clock)
        }


{-| The race clock, bucketed to the stamp's step. The clock moves every frame; the
bucket it is floored to does not, which is what lets the posts be a thunk's
argument.

The stamps are printed against this rather than the clock, which costs the accuracy
they can claim: a stamp is never ahead of the truth and never two steps behind it,
so `now` covers a post under half a minute old.

-}
clockStep : Instant -> Int
clockStep clock =
    Instant.toDuration clock // Feed.step


posts : msg -> Model -> List Car -> Timeline -> Int -> Int -> Html msg
posts earlier model cars timeline occurred bucket =
    Feed.posts
        { earlier = earlier
        , empty = "Nothing has happened yet"
        , end = "You have reached the start of the race"
        }
        model
        (feedPosts cars timeline occurred bucket)


{-| The posts, newest first, cut where the race clock stands.

The key is the event's place in the timeline, so a post keeps its key however far
the clock has run.

-}
feedPosts : List Car -> Timeline -> Int -> Int -> List (Feed.Post msg)
feedPosts cars timeline occurred bucket =
    let
        carsByNumber =
            List.foldr (\car -> Dict.insert car.metadata.carNumber car) Dict.empty cars
    in
    Timeline.toList timeline
        |> List.take occurred
        |> List.indexedMap Tuple.pair
        |> List.reverse
        |> List.map (\( id, event ) -> post id event (named event carsByNumber) bucket)


{-| Which car the event names. The field's own events -- a flag, the start -- name
none, and are posted by race control.
-}
named : TimelineEvent -> Dict String Car -> Maybe Car
named event carsByNumber =
    case event.eventType of
        CarEvent carNumber _ ->
            Dict.get carNumber carsByNumber

        _ ->
            Nothing


post : Int -> TimelineEvent -> Maybe Car -> Int -> Feed.Post msg
post id event theCar bucket =
    { key = String.fromInt id
    , avatar = avatar event theCar
    , headline = headline theCar
    , time = Feed.ago { now = bucket * Feed.step, at = Instant.toDuration event.elapsed }
    , author = author theCar
    , body = body event theCar
    , stamp = stamp event
    }


avatar : TimelineEvent -> Maybe Car -> Html msg
avatar event theCar =
    case theCar of
        Just car ->
            CarNumberBadge.viewAvatar car.metadata

        Nothing ->
            CarNumberBadge.circle
                { ground = "text-[9px] font-bold " ++ flagColor event.eventType
                , colour = Nothing
                , label = "RC"
                , mark = Nothing
                }


{-| The colours the app already wears the flags in: `PlaybackControls`'s chips, except green, whose chip is a translucent one.
-}
flagColor : EventType -> String
flagColor eventType =
    case eventType of
        Flag FullCourseYellow ->
            "bg-yellow-400 text-yellow-950"

        Flag SafetyCar ->
            "bg-orange-500 text-orange-950"

        Flag RedFlag ->
            "bg-red-600 text-white"

        Flag GreenFlag ->
            "bg-green-500 text-green-950"

        _ ->
            "bg-muted text-muted-foreground"


{-| The line that leads: the number, and the class it runs in.
-}
headline : Maybe Car -> Html msg
headline theCar =
    case theCar of
        Just { metadata } ->
            div [ Attributes.class "flex items-center gap-x-1.5" ]
                [ text ("#" ++ metadata.carNumber)
                , ClassMark.name metadata.class
                ]

        Nothing ->
            text "Field"


author : Maybe Car -> String
author theCar =
    Maybe.map (.metadata >> .team) theCar
        |> Maybe.withDefault "Race Control"


{-| What happened. A fastest lap is the class's, whether or not it is also the field's -- which is why the post says `Class Fastest Lap`.

The strip under it is rated against the records as they stood when the lap was set, not as they stand at the clock: a post two hours old would otherwise be recoloured by a sector beaten since.

-}
body : TimelineEvent -> Maybe Car -> Html msg
body event theCar =
    case ( event.eventType, theCar ) of
        -- The one arm that reads the car, for the two names the handover is between.
        -- With no car row it says the generic line.
        ( CarEvent _ DriverChange, Just car ) ->
            TimelineEvent.handover car event
                |> Maybe.map (\( handedOver, tookOver ) -> Driver.toHandover handedOver tookOver)
                |> Maybe.withDefault (TimelineEvent.describe event.eventType)
                |> text

        ( CarEvent _ FastestLap, _ ) ->
            fastestLap event

        _ ->
            text (TimelineEvent.describe event.eventType)


{-| The fastest lap: the driver, the time, and the segments it ran. It takes no car --
everything here is off the event's own `lap`, which the backend attached -- so a lap
keeps its strip even where the field has no row for the car, and asks the field for
nothing a second time.

-}
fastestLap : TimelineEvent -> Html msg
fastestLap event =
    case event.lap of
        Nothing ->
            text "Class Fastest Lap"

        Just lap ->
            div [ Attributes.class "grid gap-y-1" ]
                [ span [] <|
                    [ text ("Class Fastest Lap · " ++ Driver.toInitialAndSurname (Driver.fromName lap.driver)) ]
                        ++ Maybe.withDefault []
                            (Maybe.map
                                (\t ->
                                    [ text " · "
                                    , span [ Attributes.style "color" (Performance.textColorOf Performance.Fastest) ]
                                        [ text (Duration.toString t) ]
                                    ]
                                )
                                lap.lap.time
                            )
                , case lap.miniSectors of
                    Just miniSectors ->
                        SegmentStrip.miniSectorsRated
                            (LeMans.initialize (\which -> rate (LeMans.get which miniSectors)))

                    Nothing ->
                        SegmentStrip.sectorsRated
                            { s1 = rate (Sector.get Sector.S1 lap.sectors)
                            , s2 = rate (Sector.get Sector.S2 lap.sectors)
                            , s3 = rate (Sector.get Sector.S3 lap.sectors)
                            }
                ]


{-| `Nothing` where there is no time to rate, which is a segment the lap has none of.

-}
rate : TimelineEvent.Rated -> Maybe Performance.RatedTime
rate rated =
    Performance.rateTime rated.fastest
        { time = rated.time, personalBest = rated.personalBest }


{-| The moment the event fell, and the lap it fell on -- one behind the lap a timing
sheet has the car on, which is what the event's own line calls it.

-}
stamp : TimelineEvent -> String
stamp event =
    Duration.toStringToSeconds (Instant.toDuration event.elapsed)
        ++ (event.lapNumber
                |> Maybe.map (\lap -> " · Lap " ++ String.fromInt lap)
                |> Maybe.withDefault ""
           )
