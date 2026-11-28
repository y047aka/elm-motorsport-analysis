module EventsFeed.Catalog exposing
    ( catalogId
    , Feed, Post, Avatar(..), Body, FastestLap, Segments(..), Rating
    , fromSurface, countUpTo
    )

{-| The events column's A2UI catalog: the components a surface for it may hold, and the reading of one into what the column draws.

| Component | Properties |
| ----------- | ------------------------------------------------------------------------------------------------- |
| `Feed` | `head`, `empty`, `end` (strings); `children` (Post ids or a template) |
| `Post` | `key`, `author`, `stamp` (strings); `elapsed` (race milliseconds); `avatar`, `headline`, `body` (ids) |
| `Avatar` | `carNumber`?, `flag`? (a timeline file's flag spelling) |
| `Headline` | `carNumber`? |
| `EventBody` | `text`; `fastestLap`? (`driver`, `time`?, and `miniSectors` or `sectors`: `[{name, time?, rating?}]`) |

A car is named by its number and nothing more: its colours, class and team are the field's, looked up where the post is drawn.

The posts are revealed by the race clock against their `elapsed`, so a surface whose posts are out of that order is refused rather than revealed out of turn.

@docs catalogId
@docs Feed, Post, Avatar, Body, FastestLap, Segments, Rating
@docs fromSurface, countUpTo

-}

import A2ui exposing (Component, Scope, Surface)
import Array exposing (Array)
import Dict
import Json.Decode as Decode exposing (Decoder)
import Motorsport.Duration exposing (Duration)
import Motorsport.Flag as Flag exposing (Flag)
import Motorsport.Instant as Instant exposing (Instant)
import Motorsport.Lap.Performance as Performance exposing (PerformanceLevel(..))
import Motorsport.MiniSector exposing (MiniSectors)
import Motorsport.Race.Car exposing (CarNumber)
import Motorsport.Sector as Sector exposing (BySector)


catalogId : String
catalogId =
    "urn:elm-motorsport-analysis:a2ui:catalog:events-feed:1"


type alias Feed =
    { head : String
    , empty : String
    , end : String
    , posts : Array Post
    }


type alias Post =
    { key : String
    , elapsed : Duration
    , avatar : Avatar
    , headline : Maybe CarNumber
    , author : String
    , body : Body
    , stamp : String
    }


type Avatar
    = CarAvatar CarNumber
    | RaceControlAvatar (Maybe Flag)


type alias Body =
    { text : String
    , fastestLap : Maybe FastestLap
    }


type alias FastestLap =
    { driver : String
    , time : Maybe Duration
    , segments : Segments
    }


type alias Rating =
    Maybe Performance.RatedTime


type Segments
    = BySectors (BySector Rating)
    | ByMiniSectors (MiniSectors Rating)


{-| How many posts the race clock has reached.
-}
countUpTo : Instant -> Feed -> Int
countUpTo clock f =
    search (Instant.toDuration clock) f.posts 0 (Array.length f.posts)


search : Duration -> Array Post -> Int -> Int -> Int
search clock all low high =
    if low >= high then
        low

    else
        let
            mid =
                low + ((high - low) // 2)
        in
        case Array.get mid all of
            Just p ->
                if p.elapsed <= clock then
                    search clock all (mid + 1) high

                else
                    search clock all low mid

            Nothing ->
                low



-- READING A SURFACE


fromSurface : Surface -> Result String Feed
fromSurface s =
    if s.catalogId /= catalogId then
        Err ("catalog " ++ s.catalogId ++ " is not " ++ catalogId)

    else
        component s "root" "Feed"
            |> Result.andThen (feed s)
            |> Result.andThen inOrder


inOrder : Feed -> Result String Feed
inOrder f =
    let
        ordered ( previous, ok ) p =
            ( p.elapsed, ok && previous <= p.elapsed )
    in
    if Array.foldl (\p acc -> ordered acc p) ( 0, True ) f.posts |> Tuple.second then
        Ok f

    else
        Err "the posts are not in the order of their elapsed time"


feed : Surface -> Component -> Result String Feed
feed s c =
    Result.map4 Feed
        (prop s A2ui.root c "head" Decode.string)
        (prop s A2ui.root c "empty" Decode.string)
        (prop s A2ui.root c "end" Decode.string)
        (posts s c)


posts : Surface -> Component -> Result String (Array Post)
posts s c =
    let
        each id scopes =
            scopes
                |> List.map (\scope -> component s id "Post" |> Result.andThen (post s scope))
                |> combine
                |> Result.map Array.fromList
    in
    case A2ui.children c "children" of
        Just (A2ui.Static ids) ->
            ids
                |> List.map (\id -> component s id "Post" |> Result.andThen (post s A2ui.root))
                |> combine
                |> Result.map Array.fromList

        Just (A2ui.Template template) ->
            each template.componentId (A2ui.items s A2ui.root template.path)

        Nothing ->
            Err "Feed has no children"


post : Surface -> Scope -> Component -> Result String Post
post s scope c =
    Ok Post
        |> andMap (prop s scope c "key" Decode.string)
        |> andMap (prop s scope c "elapsed" Decode.int)
        |> andMap (child s scope c "avatar" "Avatar" (avatar s))
        |> andMap (child s scope c "headline" "Headline" (\sc h -> optional s sc h "carNumber" Decode.string))
        |> andMap (prop s scope c "author" Decode.string)
        |> andMap (child s scope c "body" "EventBody" (body s))
        |> andMap (prop s scope c "stamp" Decode.string)


avatar : Surface -> Scope -> Component -> Result String Avatar
avatar s scope c =
    Result.map2
        (\carNumber flag ->
            case carNumber of
                Just number ->
                    CarAvatar number

                Nothing ->
                    RaceControlAvatar flag
        )
        (optional s scope c "carNumber" Decode.string)
        (optional s scope c "flag" flagDecoder)


flagDecoder : Decoder Flag
flagDecoder =
    Decode.string
        |> Decode.andThen
            (\name ->
                Flag.fromString name
                    |> Maybe.map Decode.succeed
                    |> Maybe.withDefault (Decode.fail ("no flag " ++ name))
            )


body : Surface -> Scope -> Component -> Result String Body
body s scope c =
    Result.map2 Body
        (prop s scope c "text" Decode.string)
        (optional s scope c "fastestLap" fastestLapDecoder)


fastestLapDecoder : Decoder FastestLap
fastestLapDecoder =
    Decode.map3 FastestLap
        (Decode.field "driver" Decode.string)
        (Decode.maybe (Decode.field "time" Decode.int))
        (Decode.oneOf
            [ Decode.field "miniSectors" (Decode.list segmentDecoder) |> Decode.map ByMiniSectors
            , Decode.field "sectors" (Decode.list segmentDecoder) |> Decode.map (bySector >> BySectors)
            ]
        )


segmentDecoder : Decoder { name : String, value : Rating }
segmentDecoder =
    Decode.map3 (\name time level -> { name = name, value = Maybe.map2 Performance.RatedTime time level })
        (Decode.field "name" Decode.string)
        (Decode.maybe (Decode.field "time" Decode.int))
        (Decode.maybe (Decode.field "rating" levelDecoder))


levelDecoder : Decoder PerformanceLevel
levelDecoder =
    Decode.string
        |> Decode.andThen
            (\level ->
                case level of
                    "fastest" ->
                        Decode.succeed Fastest

                    "personalBest" ->
                        Decode.succeed PersonalBest

                    "standard" ->
                        Decode.succeed Standard

                    _ ->
                        Decode.fail ("no rating " ++ level)
            )


{-| A sector the list does not name has no rating, as a sector the feed gave no time for has none.
-}
bySector : List { name : String, value : Rating } -> BySector Rating
bySector cells =
    let
        named =
            Dict.fromList (List.map (\cell -> ( cell.name, cell.value )) cells)
    in
    Sector.initialize (\sector -> Dict.get (Sector.toString sector) named |> Maybe.andThen identity)



-- HELPERS


component : Surface -> String -> String -> Result String Component
component s id expected =
    case Dict.get id s.components of
        Just c ->
            if c.component == expected then
                Ok c

            else
                Err (id ++ " is a " ++ c.component ++ ", not a " ++ expected)

        Nothing ->
            Err ("no component " ++ id)


child : Surface -> Scope -> Component -> String -> String -> (Scope -> Component -> Result String a) -> Result String a
child s scope c name expected readChild =
    case Dict.get name c.properties of
        Just (A2ui.JString id) ->
            component s id expected |> Result.andThen (readChild scope)

        _ ->
            Err (c.id ++ "." ++ name ++ " names no component")


prop : Surface -> Scope -> Component -> String -> Decoder a -> Result String a
prop s scope c name decoder =
    optional s scope c name decoder
        |> Result.andThen (Result.fromMaybe (c.id ++ "." ++ name ++ " is missing"))


{-| A property that is not there, or points at nothing, or is null, is `Nothing`; one that is there and of the wrong shape is an error.
-}
optional : Surface -> Scope -> Component -> String -> Decoder a -> Result String (Maybe a)
optional s scope c name decoder =
    case A2ui.read s scope c name of
        Nothing ->
            Ok Nothing

        Just A2ui.JNull ->
            Ok Nothing

        Just value ->
            Decode.decodeValue decoder (A2ui.encodeValue value)
                |> Result.map Just
                |> Result.mapError (\e -> c.id ++ "." ++ name ++ ": " ++ Decode.errorToString e)


andMap : Result String a -> Result String (a -> b) -> Result String b
andMap =
    Result.map2 (|>)


combine : List (Result String a) -> Result String (List a)
combine =
    List.foldr (Result.map2 (::)) (Ok [])
