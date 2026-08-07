module Data.Series.EventSummary exposing (EventSummary)

{-|

@docs EventSummary

-}

import Motorsport.Circuit exposing (Layout)
import Motorsport.Circuit.LeMans exposing (LeMans2025MiniSector)


{-| One round of a season, as the app knows it before any of its data has
loaded.

`circuit` is here rather than worked out later because it is a fact about the
round, like its date -- see [`Data.Series.Wec.circuit`](Data-Series-Wec#circuit).
It is what a loaded [`Race`](Motorsport-Race) carries, and the two are set
together so that nothing can pair one round's circuit with another's laps.

-}
type alias EventSummary =
    { id : String
    , name : String
    , season : Int
    , date : String
    , jsonPath : String
    , circuit : Layout LeMans2025MiniSector
    }
