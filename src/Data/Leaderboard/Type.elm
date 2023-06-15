module Data.Leaderboard.Type exposing (Leaderboard)

import Motorsport.Duration exposing (Duration)
import Motorsport.Gap exposing (Gap)
import Motorsport.Lap exposing (Lap)


type alias Leaderboard =
    List
        { position : Int
        , carNumber : String
        , driver : String
        , lap : Int
        , gap : Gap
        , time : Duration
        , best : Duration
        , history : List Lap
        }
