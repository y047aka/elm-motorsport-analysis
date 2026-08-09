module Data.Wec.Calendar exposing
    ( Calendar, Season, Round
    , empty, decoder, findRound
    )

{-| The rounds there are, read before any one of them has been asked for.

Every other file the CLI writes is one race. This one is the list of them, and
it is the only thing the app can consult before it knows which race it wants --
which is why the index page is built from it and nothing else.

@docs Calendar, Season, Round
@docs empty, decoder, findRound

-}

import Json.Decode as Decode exposing (Decoder, field, int, list, string)


{-| The seasons, newest first.

The order is the file's, not this app's to sort: being the latest season is
what being first here means. See `Motorsport.Calendar` on the CLI side.

-}
type alias Calendar =
    List Season


{-| A season and the rounds it ran, in the order it ran them.
-}
type alias Season =
    { season : Int
    , rounds : List Round
    }


{-| One round, as much of it as there is before its own files are loaded: what
it is filed under, what to call it, when it was run, and where its two files
are.

The paths are read, not built. The app could work them out from the season and
the id -- it is the same rule for every round -- but that rule would then be
written down twice, here and in the CLI that writes the files, with nothing to
notice when the two stop agreeing.

-}
type alias Round =
    { id : String
    , name : String
    , date : String
    , summary : String
    , laps : String
    }


{-| What there is before the calendar has arrived, and in place of one that
could not be read: no seasons, rather than a guess at which.
-}
empty : Calendar
empty =
    []


{-| The round a URL is asking for, if there is one.

A round the calendar does not list resolves to `Nothing`, and nothing is asked
for -- which is the same answer as before the calendar arrives. The app cannot
tell a round that does not exist from one it has not heard of yet, and it does
not have to: both mean there is nothing to show.

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
