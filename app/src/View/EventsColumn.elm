module View.EventsColumn exposing (Model, init, view)

{-| The round's events as a column of the strip: what has happened by the race
clock, newest first, one post per event.

The feed -- the frame, the posts, their paging -- is `View.Feed`. The posts arrive as an A2UI surface, `EventsFeed`'s; what is here is the renderer of its catalog, `EventsFeed.Catalog`.

The visual tests locate the column by `data-events-column`.

-}

import Array
import Dict exposing (Dict)
import EventsFeed exposing (Surface)
import EventsFeed.Catalog as Catalog
import Html exposing (Html, div, span, text)
import Html.Attributes as Attributes exposing (attribute)
import Html.Lazy
import Motorsport.Duration as Duration
import Motorsport.Flag exposing (Flag(..))
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap.Performance as Performance
import Motorsport.Lap.SegmentStrip as SegmentStrip
import Motorsport.Race.Car exposing (Car)
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
    -> Surface
    -> Instant
    -> Html msg
view controls model cars surface clock =
    case surface of
        Ok feed ->
            Feed.view
                { attributes = [ attribute "data-events-column" "" ]
                , corner = controls.corner
                , head = text feed.head
                , body =
                    Html.Lazy.lazy5 (posts controls.earlier)
                        model
                        cars
                        feed
                        (Catalog.countUpTo clock feed)
                        (clockStep clock)
                }

        Err problem ->
            Feed.view
                { attributes = [ attribute "data-events-column" "" ]
                , corner = controls.corner
                , head = text "Race Timeline"
                , body =
                    div [ Attributes.class "p-5 text-center italic text-muted-foreground" ]
                        [ text ("The events could not be read: " ++ problem) ]
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


posts : msg -> Model -> List Car -> Catalog.Feed -> Int -> Int -> Html msg
posts earlier model cars feed occurred bucket =
    let
        carsByNumber =
            List.foldr (\car -> Dict.insert car.metadata.carNumber car) Dict.empty cars
    in
    Feed.posts { earlier = earlier, empty = feed.empty, end = feed.end }
        model
        (Array.slice 0 occurred feed.posts
            |> Array.toList
            |> List.reverse
            |> List.map (post carsByNumber bucket)
        )


post : Dict String Car -> Int -> Catalog.Post -> Feed.Post msg
post carsByNumber bucket p =
    { key = p.key
    , avatar = avatar carsByNumber p.avatar
    , headline = headline carsByNumber p.headline
    , time = Feed.ago { now = bucket * Feed.step, at = p.elapsed }
    , author = p.author
    , body = body p.body
    , stamp = p.stamp
    }


{-| A car the field has no row for wears race control's plain avatar: the agent names cars, and the field is what says how one looks.
-}
avatar : Dict String Car -> Catalog.Avatar -> Html msg
avatar carsByNumber a =
    case a of
        Catalog.CarAvatar carNumber ->
            case Dict.get carNumber carsByNumber of
                Just car ->
                    CarNumberBadge.viewAvatar car.metadata

                Nothing ->
                    raceControl Nothing

        Catalog.RaceControlAvatar flag ->
            raceControl flag


raceControl : Maybe Flag -> Html msg
raceControl flag =
    CarNumberBadge.circle
        { ground = "text-[9px] font-bold " ++ flagColor flag
        , colour = Nothing
        , label = "RC"
        , mark = Nothing
        }


{-| The colours the app already wears the flags in: `PlaybackControls`'s chips, except green, whose chip is a translucent one.
-}
flagColor : Maybe Flag -> String
flagColor flag =
    case flag of
        Just FullCourseYellow ->
            "bg-yellow-400 text-yellow-950"

        Just SafetyCar ->
            "bg-orange-500 text-orange-950"

        Just RedFlag ->
            "bg-red-600 text-white"

        Just GreenFlag ->
            "bg-green-500 text-green-950"

        Nothing ->
            "bg-muted text-muted-foreground"


{-| The line that leads: the number, and the class it runs in.
-}
headline : Dict String Car -> Maybe String -> Html msg
headline carsByNumber carNumber =
    case Maybe.andThen (\number -> Dict.get number carsByNumber) carNumber of
        Just { metadata } ->
            div [ Attributes.class "flex items-center gap-x-1.5" ]
                [ text ("#" ++ metadata.carNumber)
                , ClassMark.name metadata.class
                ]

        Nothing ->
            text "Field"


body : Catalog.Body -> Html msg
body b =
    case b.fastestLap of
        Nothing ->
            text b.text

        Just lap ->
            div [ Attributes.class "grid gap-y-1" ]
                [ span [] <|
                    [ text (b.text ++ " · " ++ lap.driver) ]
                        ++ Maybe.withDefault []
                            (Maybe.map
                                (\t ->
                                    [ text " · "
                                    , span [ Attributes.style "color" (Performance.textColorOf Performance.Fastest) ]
                                        [ text (Duration.toString t) ]
                                    ]
                                )
                                lap.time
                            )
                , case lap.segments of
                    Catalog.ByMiniSectors miniSectors ->
                        SegmentStrip.miniSectorsRated miniSectors

                    Catalog.BySectors sectors ->
                        SegmentStrip.sectorsRated sectors
                ]
