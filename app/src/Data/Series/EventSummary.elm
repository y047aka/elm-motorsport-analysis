module Data.Series.EventSummary exposing (EventSummary)

{-|

@docs EventSummary

-}


{-| One round of a season, as the app knows it before any of its data has
loaded.

Nothing about the circuit is here. All of it arrives together in the summary --
see [`Data.Wec.Event`](Data-Wec#Event).

-}
type alias EventSummary =
    { id : String
    , name : String
    , season : Int
    , date : String
    , jsonPath : String
    }
