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
import Motorsport.BestTimes as BestTimes
import Motorsport.Driver as Driver
import Motorsport.Duration as Duration
import Motorsport.Flag as Flag exposing (Flag(..))
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap.Performance as Performance
import Motorsport.Lap.SegmentStrip as SegmentStrip
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (CarEventType(..), EventType(..), TimelineEvent)
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
    -> BestTimes.Changes
    -> Instant
    -> Html msg
view controls model cars timeline changes clock =
    Feed.view
        { attributes = [ attribute "data-events-column" "" ]
        , corner = controls.corner
        , head = text "Race Timeline"
        , body =
            Html.Lazy.lazy6 (posts controls.earlier)
                model
                cars
                timeline
                changes
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


posts : msg -> Model -> List Car -> Timeline -> BestTimes.Changes -> Int -> Int -> Html msg
posts earlier model cars timeline changes occurred bucket =
    Feed.posts
        { earlier = earlier
        , empty = "Nothing has happened yet"
        , end = "You have reached the start of the race"
        }
        model
        (feedPosts cars timeline changes occurred bucket)


{-| The posts, newest first, cut where the race clock stands.

The key is the event's place in the timeline, so a post keeps its key however far
the clock has run.

-}
feedPosts : List Car -> Timeline -> BestTimes.Changes -> Int -> Int -> List (Feed.Post msg)
feedPosts cars timeline changes occurred bucket =
    let
        carsByNumber =
            List.foldr (\car -> Dict.insert car.metadata.carNumber car) Dict.empty cars
    in
    Timeline.toList timeline
        |> List.take occurred
        |> List.indexedMap Tuple.pair
        |> List.reverse
        |> List.map (\( id, event ) -> post id event (named event carsByNumber) bucket changes)


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


post : Int -> TimelineEvent -> Maybe Car -> Int -> BestTimes.Changes -> Feed.Post msg
post id event theCar bucket changes =
    { key = String.fromInt id
    , avatar = avatar event theCar
    , headline = headline theCar
    , time = Feed.ago { now = bucket * Feed.step, at = Instant.toDuration event.elapsed }
    , author = author theCar
    , body = body event theCar changes
    , stamp = stamp event theCar
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


{-| The same colours the playback controls' flag chips are worn in.
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


{-| What happened. A driver change names the two drivers; a fastest lap is the
class's, and names who set it and how fast -- the time in the colour the strip under
it rates a fastest segment in.

The strip is rated against the records as they stood when the lap was set, not as
they stand at the clock: a post two hours old would otherwise be recoloured by a
sector beaten since.

-}
body : TimelineEvent -> Maybe Car -> BestTimes.Changes -> Html msg
body event theCar changes =
    let
        described =
            TimelineEvent.describe event.eventType
    in
    case ( event.eventType, theCar ) of
        ( CarEvent _ DriverChange, Just car ) ->
            TimelineEvent.handover car event
                |> Maybe.map (\( handedOver, tookOver ) -> Driver.toHandover handedOver tookOver)
                |> Maybe.withDefault described
                |> text

        ( CarEvent _ FastestLap, Just car ) ->
            case TimelineEvent.runningLap car event of
                Nothing ->
                    text "Class Fastest Lap"

                Just lap ->
                    let
                        records =
                            BestTimes.at { elapsed = event.elapsed } changes

                        rated =
                            Performance.ofSectors records lap

                        time =
                            lap.time
                    in
                    div [ Attributes.class "grid gap-y-1" ]
                        [ span [] <|
                            [ text ("Class Fastest Lap · " ++ Driver.toInitialAndSurname lap.driver) ]
                                ++ Maybe.withDefault []
                                    (Maybe.map
                                        (\t ->
                                            [ text " · "
                                            , span [ Attributes.style "color" (Performance.textColorOf Performance.Fastest) ]
                                                [ text (Duration.toString t) ]
                                            ]
                                        )
                                        time
                                    )
                        , case Performance.ofMiniSectors records lap of
                            Just mini ->
                                SegmentStrip.miniSectorsRated mini

                            Nothing ->
                                SegmentStrip.sectorsRated rated
                        ]

        _ ->
            text described


{-| The moment the event fell, and the last lap the car had completed -- one behind
the lap a timing sheet has the car on.
-}
stamp : TimelineEvent -> Maybe Car -> String
stamp event theCar =
    Duration.toStringToSeconds (Instant.toDuration event.elapsed)
        ++ (theCar
                |> Maybe.andThen (\car_ -> TimelineEvent.runningLap car_ event)
                |> Maybe.map (\lap_ -> " · Lap " ++ String.fromInt lap_.lap)
                |> Maybe.withDefault ""
           )
