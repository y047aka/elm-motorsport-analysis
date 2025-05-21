module Data.Series.EventSummary exposing (EventSummary)


type alias EventSummary =
    { id : String
    , name : String
    , season : Int
    , date : String
    , jsonPath : String
    }
