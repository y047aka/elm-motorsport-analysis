module Data.Series.Wec_2025 exposing (carImageFileName_2025, toEventSummary_Wec_2025, wec_2025)

import Data.Series.Wec exposing (EventSummary, Wec(..))


wec_2025 : List EventSummary
wec_2025 =
    List.map toEventSummary_Wec_2025
        [ Qatar_1812km ]


toEventSummary_Wec_2025 : Wec -> EventSummary
toEventSummary_Wec_2025 event =
    let
        id =
            Data.Series.Wec.toString event

        jsonPath =
            "/static/wec/2025/" ++ id ++ ".json"
    in
    case event of
        Qatar_1812km ->
            { id = id
            , name = "Qatar 1812km"
            , date = "2025-03-01"
            , jsonPath = jsonPath
            }

        -- TODO: Add more events
        _ ->
            { id = id
            , name = "Qatar 1812km"
            , date = "2025-03-01"
            , jsonPath = jsonPath
            }


carImageFileName_2025 : String -> Maybe String
carImageFileName_2025 carNumber =
    case carNumber of
        "5" ->
            Just "/91620/2_66467b.png"

        "6" ->
            Just "/91621/2_e70d15.png"

        "7" ->
            Just "/91622/2_7967b9.png"

        "007" ->
            Just "/91618/2_9d9bab.png"

        "8" ->
            Just "/91623/2_9f9d8f.png"

        "009" ->
            Just "/91619/2_be0379.png"

        "10" ->
            Just "/91636/2_5767b9.png"

        "12" ->
            Just "/91624/2_567b99.png"

        "15" ->
            Just "/91625/2_9c473f.png"

        "20" ->
            Just "/91626/2_167b99.png"

        "21" ->
            Just "/91637/2_d9c8d4.png"

        "27" ->
            Just "/91638/2_7b99d9.png"

        "31" ->
            Just "/91639/2_67b99d.png"

        "33" ->
            Just "/91641/2_b99d9c.png"

        "35" ->
            Just "/91627/2_367b99.png"

        "36" ->
            Just "/91628/2_d9d399.png"

        "38" ->
            Just "/91629/2_367b99-1.png"

        "46" ->
            Just "/91640/2_b99d9d.png"

        "50" ->
            Just "/91630/2_9d9324.png"

        "51" ->
            Just "/91631/2_b99d9d.png"

        "54" ->
            Just "/91642/2_99d9dd.png"

        "59" ->
            Just "/91643/2_df02e2.png"

        "60" ->
            Just "/91645/2_9d9e36.png"

        "61" ->
            Just "/91646/2_267b99.png"

        "77" ->
            Just "/91647/2_67b99d-1.png"

        "78" ->
            Just "/91649/2_9d9eb6.png"

        "81" ->
            Just "/91651/2_367b99-2.png"

        "83" ->
            Just "/91632/2_467b99.png"

        "85" ->
            Just "/91652/2_f3bfc7.png"

        "87" ->
            Just "/91650/2_8667b9.png"

        "88" ->
            Just "/91648/2_7b99d9-1.png"

        "92" ->
            Just "/91653/2_567b99-1.png"

        "93" ->
            Just "/91633/2_99d9fd.png"

        "94" ->
            Just "/91634/2_99da00.png"

        "95" ->
            Just "/91644/2_67767b.png"

        "99" ->
            Just "/91635/2_b99da0.png"

        _ ->
            Nothing
