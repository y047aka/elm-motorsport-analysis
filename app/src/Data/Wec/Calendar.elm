module Data.Wec.Calendar exposing
    ( Calendar, Season, Round
    , empty, decoder
    )

{-| The rounds there are, read before any one of them has been asked for.

Every other file the CLI writes is one race. This one is the list of them, and
it is the only thing the app can consult before it knows which race it wants --
which is why the index page is built from it and nothing else.

@docs Calendar, Season, Round
@docs empty, decoder

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


{-| One round, as much of it as there is before its own file is loaded: what it
is filed under, what to call it, and when it was run.

Nothing here says where its files are. That follows from the season and the id
by the same rule for every round, so it is worked out where it is needed rather
than carried.

-}
type alias Round =
    { id : String
    , name : String
    , date : String
    }


{-| What there is before the calendar has arrived, and in place of one that
could not be read: no seasons, rather than a guess at which.
-}
empty : Calendar
empty =
    []


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
    Decode.map3 Round
        (field "id" string)
        (field "name" string)
        (field "date" string)
