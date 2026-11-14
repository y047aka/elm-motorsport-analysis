module View.EventsColumn exposing (Model, init, view)

{-| The round's events as a column of the strip: what has happened by the race
clock, newest first, one post per event.

The paging is the whole of the state the column keeps, and it is `DataView`'s; the
column draws its posts itself, through `DataView.feedView`.

-}

import Dict exposing (Dict)
import Html exposing (Html, button, div, img, span, text)
import Html.Attributes as Attributes exposing (attribute)
import Html.Events exposing (onClick)
import Html.Lazy
import Internal.DataView as DataView
import Internal.DataView.Options exposing (FilteringOption(..), Options, PaginationOption(..), SelectingOption(..), SortingOption(..))
import Motorsport.Duration as Duration exposing (Duration)
import Motorsport.Flag as Flag exposing (Flag(..))
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Timeline as Timeline exposing (Timeline)
import Motorsport.Race.TimelineEvent as TimelineEvent exposing (EventType(..), TimelineEvent)
import UI.Shadcn.Card as Card
import View.ClassMark as ClassMark


{-| How far the reader has pulled the feed back.
-}
type alias Model =
    DataView.Model


init : Model
init =
    DataView.init "timeline-events" timelineOptions


{-| The feed has no head to sort by and no field to filter in; it is paginated,
and the page it is on is the only thing a reader sets in it.
-}
timelineOptions : Options
timelineOptions =
    { sorting = NoSorting
    , filtering = NoFiltering
    , selecting = NoSelecting
    , pagination = Pagination page
    }


{-| How many posts the feed opens with, and how many more each pull back asks for.
-}
page : Int
page =
    30


{-| The column, and the corner it is held and closed by.

The corner belongs to the strip rather than to the column: the same controls close
and carry every other column, and they answer to the page's own message. `earlier`
is what the foot answers to when the reader asks for the posts behind the ones
shown.

The visual tests locate the column by `data-events-column` and its posts by
`data-event-row`. The fastest-lap events are not among the posts; see
`TimelineEvent.isFastestLap`.

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
view controls table cars timeline clock =
    let
        occurred =
            Timeline.countUpTo clock timeline
    in
    Card.card [ attribute "data-events-column" "" ]
        [ div [ Attributes.class "relative flex-1 min-h-0 grid grid-rows-[auto_minmax(0,1fr)]" ]
            [ feedHead
            , div [ Attributes.class "min-h-0 overflow-y-auto" ]
                [ Card.content []
                    [ Html.Lazy.lazy6 feedBody table cars timeline occurred (clockMinute clock) controls.earlier ]
                ]
            , div [ Attributes.class "absolute top-0 right-0 flex items-start gap-x-1" ] controls.corner
            ]
        ]


{-| The minute of the race the posts are stamped against. The clock moves every
frame; the minute it is bucketed to does not, which is what lets the feed be a
thunk's argument.
-}
clockMinute : Instant -> Int
clockMinute clock =
    Instant.toDuration clock // 60000


{-| The feed's head: what the column is. It stands above the scroller and not
inside it: Card's own ground is translucent, so a head within the scroller lets
the posts show through it.
-}
feedHead : Html msg
feedHead =
    div [ Attributes.class "px-4 pb-1 pr-14" ]
        [ span [ Attributes.class "text-sm font-semibold leading-none" ] [ text "Race Timeline" ] ]


{-| The posts, and the control that asks for the ones behind them.

The rows are rebuilt only when an event arrives or a minute of the race passes.
The cars and the timeline never move under playback, and the count and the minute
are numbers -- anything frame-made passed instead is a fresh reference every frame
and misses.

-}
feedBody : Model -> List Car -> Timeline -> Int -> Int -> msg -> Html msg
feedBody table cars timeline occurred minute earlier =
    let
        posts =
            feedPosts cars timeline occurred
    in
    if List.isEmpty posts then
        div [ Attributes.class "p-5 text-center italic text-muted-foreground" ]
            [ text "Nothing has happened yet" ]

    else
        DataView.feedView
            { key = .id >> String.fromInt
            , row = postRow (minute * 60000)
            , foot = feedFoot earlier
            }
            table
            posts


type alias Post =
    { id : Int
    , event : TimelineEvent
    , car : Maybe Car
    }


{-| The posts, newest first, cut where the race clock stands.

The key is the event's place in the timeline, taken before the fastest laps are
dropped: it is asked to be stable, not consecutive.

-}
feedPosts : List Car -> Timeline -> Int -> List Post
feedPosts cars timeline occurred =
    let
        carsByNumber =
            List.foldr (\car -> Dict.insert car.metadata.carNumber car) Dict.empty cars
    in
    Timeline.toList timeline
        |> List.take occurred
        |> List.indexedMap Tuple.pair
        |> List.filter (not << TimelineEvent.isFastestLap << .eventType << Tuple.second)
        |> List.reverse
        |> List.map
            (\( id, event ) ->
                { id = id
                , event = event
                , car =
                    case event.eventType of
                        CarEvent carNumber _ ->
                            Dict.get carNumber carsByNumber

                        _ ->
                            Nothing
                }
            )


postRow : Duration -> Post -> Html msg
postRow clock post_ =
    div
        [ Attributes.class "grid border-t border-border/70 first:border-t-0"
        , attribute "data-event-row" ""
        ]
        [ div [ Attributes.class "grid grid-cols-[auto_1fr] gap-x-2.5 py-2" ]
            [ postAvatar post_
            , postText clock post_
            ]
        ]


{-| The post's avatar: the maker's mark and the car's number on its maker's
colour, or the number alone where the table has no mark -- and for an event of the
field's own -- a flag, the start -- race control's mark wearing that flag's colour.
-}
postAvatar : Post -> Html msg
postAvatar post_ =
    case post_.car of
        Just { metadata } ->
            div
                [ Attributes.class "size-8 shrink-0 rounded-full grid place-items-center text-[11px] font-bold leading-none"
                , Attributes.style "background-color" metadata.manufacturer.color
                ]
                [ case metadata.manufacturer.logoUrl of
                    Just url ->
                        div [ Attributes.class "flex flex-col items-center gap-y-0.5" ]
                            [ img
                                [ Attributes.src url
                                , Attributes.alt metadata.manufacturer.name
                                , Attributes.class "max-h-[14px] max-w-[22px] object-contain"
                                ]
                                []
                            , span [ Attributes.class "text-[9px] leading-none" ] [ text metadata.carNumber ]
                            ]

                    Nothing ->
                        text metadata.carNumber
                ]

        Nothing ->
            div
                [ Attributes.class "size-8 shrink-0 rounded-full grid place-items-center text-[9px] font-bold leading-none"
                , Attributes.class (flagColor post_.event.eventType)
                ]
                [ text "RC" ]


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


{-| The post's text: the number and class, the team beneath them, the event, and
the elapsed time and lap.
-}
postText : Duration -> Post -> Html msg
postText clock post_ =
    let
        elapsed =
            Instant.toDuration post_.event.elapsed
    in
    div [ Attributes.class "min-w-0" ]
        [ div [ Attributes.class "flex items-baseline gap-x-1.5" ]
            [ div [ Attributes.class "flex items-center gap-x-1.5 text-[11px] leading-none text-muted-foreground" ]
                [ handle post_ ]
            , span [ Attributes.class "ms-auto shrink-0 text-[11px] tabular-nums text-muted-foreground" ]
                [ text (ago clock elapsed) ]
            ]
        , div [ Attributes.class "truncate text-xs font-semibold" ]
            [ text (author post_) ]
        , div [ Attributes.class "pt-1 text-sm leading-snug" ]
            [ text (TimelineEvent.describe post_.event.eventType) ]
        , div [ Attributes.class "pt-1 text-[11px] tabular-nums text-muted-foreground" ]
            [ text (stamp post_) ]
        ]


author : Post -> String
author post_ =
    Maybe.map (.metadata >> .team) post_.car
        |> Maybe.withDefault "Race Control"


handle : Post -> Html msg
handle post_ =
    case post_.car of
        Just { metadata } ->
            div [ Attributes.class "flex items-center gap-x-1.5" ]
                [ text ("#" ++ metadata.carNumber)
                , ClassMark.name metadata.class
                ]

        Nothing ->
            text "Field"


stamp : Post -> String
stamp post_ =
    Duration.toStringToSeconds (Instant.toDuration post_.event.elapsed)
        ++ (post_.car
                |> Maybe.andThen (\car -> TimelineEvent.runningLap car post_.event)
                |> Maybe.map (\lap_ -> " · Lap " ++ String.fromInt lap_.lap)
                |> Maybe.withDefault ""
           )


{-| How far behind the race clock the event stands, in the compact spelling a
timeline stamps its posts with.
-}
ago : Duration -> Duration -> String
ago clock elapsed =
    let
        minutes =
            (clock - elapsed) // 60000
    in
    if minutes < 1 then
        "now"

    else if minutes < 60 then
        String.fromInt minutes ++ "m"

    else
        String.fromInt (minutes // 60) ++ "h"


feedFoot : msg -> Int -> Html msg
feedFoot earlier remaining =
    div [ Attributes.class "grid pt-3" ]
        [ if remaining > 0 then
            button
                [ onClick earlier
                , Attributes.class "cursor-pointer rounded-lg border border-border py-1.5 text-xs font-medium text-muted-foreground transition-colors hover:bg-accent hover:text-accent-foreground"
                ]
                [ text ("Show " ++ String.fromInt (min remaining page) ++ " earlier events") ]

          else
            div [ Attributes.class "py-1 text-center text-[11px] italic text-muted-foreground" ]
                [ text "You have reached the start of the race" ]
        ]
