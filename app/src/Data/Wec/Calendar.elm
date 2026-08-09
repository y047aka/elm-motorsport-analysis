module Data.Wec.Calendar exposing
    ( Calendar, Season, Round
    , empty, decoder, findRound
    )

{-| The rounds there are.

Every other file the CLI writes is one race. This is the list of them, and the
only thing the app can consult before it knows which race it wants.

@docs Calendar, Season, Round
@docs empty, decoder, findRound

-}

import Json.Decode as Decode exposing (Decoder, field, int, list, string)


{-| The seasons, newest first. The order is the file's, not this app's to sort:
being the latest season is what being first here means.
-}
type alias Calendar =
    List Season


{-| The rounds are in the order the season ran them.
-}
type alias Season =
    { season : Int
    , rounds : List Round
    }


{-| The paths are read, not built. The app could work them out from the season
and the id, but that rule would then be written down twice -- here and in the
CLI that writes the files -- with nothing to notice when the two stop agreeing.
-}
type alias Round =
    { id : String
    , name : String
    , date : String
    , summary : String
    , laps : String
    }


{-| No seasons, rather than a guess at which: what there is before the calendar
arrives, and in place of one that could not be read.
-}
empty : Calendar
empty =
    []


{-| The round a URL is asking for, if there is one.

`Nothing` covers both a round that does not exist and one the calendar has not
arrived to list yet. The app cannot tell them apart and does not have to: both
mean there is nothing to show.

The season is matched as the string the URL carried, so `/wec/02025/spa_6h` is
not this round.

-}
findRound : { season : String, event : String } -> Calendar -> Maybe ( Season, Round )
findRound params calendar =
    calendar
        |> List.filter (\season -> String.fromInt season.season == params.season)
        |> List.concatMap (\season -> List.map (Tuple.pair season) season.rounds)
        |> List.filter (\( _, round ) -> round.id == params.event)
        |> List.head


{-| -}
decoder : Decoder Calendar
decoder =
    field "seasons" (list seasonDecoder)


seasonDecoder : Decoder Season
seasonDecoder =
    Decode.map2 Season
        (field "season" int)
        (field "rounds" (list roundDecoder))


roundDecoder : Decoder Round
roundDecoder =
    Decode.map5 Round
        (field "id" string)
        (field "name" string)
        (field "date" string)
        (field "summary" string)
        (field "laps" string)
