module EventsFeed exposing (Surface, surfaceOf)

{-| The round's events as an A2UI surface: `EventsFeed.Agent` says the race's timeline in A2UI messages, and `EventsFeed.Catalog` reads them back into the posts the events column draws.

It is built when the round's events arrive, once per round: the surface holds the whole race, and the clock is applied to it where it is drawn.

@docs Surface, surfaceOf

-}

import A2ui
import EventsFeed.Agent as Agent
import EventsFeed.Catalog as Catalog
import Json.Decode as Decode
import Json.Encode as Encode
import Motorsport.Race.Car exposing (Car)
import Motorsport.Race.Timeline exposing (Timeline)


{-| The surface the column draws, or why it could not be read.
-}
type alias Surface =
    Result String Catalog.Feed


{-| The agent's messages, sent over the wire and read back as a renderer would read them: through JSON and the decoder, not handed across as Elm values.
-}
surfaceOf : List Car -> Timeline -> Surface
surfaceOf cars timeline =
    Agent.messages cars timeline
        |> Encode.list A2ui.encode
        |> Encode.encode 0
        |> Decode.decodeString (Decode.list A2ui.decoder)
        |> Result.mapError Decode.errorToString
        |> Result.andThen (A2ui.surface Agent.surfaceId)
        |> Result.andThen Catalog.fromSurface
