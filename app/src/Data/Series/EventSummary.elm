module Data.Series.EventSummary exposing (EventSummary)

{-|

@docs EventSummary

-}

import Motorsport.Circuit.Direction exposing (Direction)


{-| One round of a season, as the app knows it before any of its data has
loaded.

`direction` is here rather than worked out later because it is a fact about the
round, like its date -- see
[`Data.Series.Wec.direction`](Data-Series-Wec#direction). It is the last thing
about the circuit this side still holds: how the lap is divided the summary
states, and how long each division is the summary states too.

-}
type alias EventSummary =
    { id : String
    , name : String
    , season : Int
    , date : String
    , jsonPath : String
    , direction : Direction
    }
