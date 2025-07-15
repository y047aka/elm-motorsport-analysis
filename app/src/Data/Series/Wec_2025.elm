module Data.Series.Wec_2025 exposing (carImageFileName_2025, toEventSummary_Wec_2025, wec_2025)

import Data.Series.EventSummary exposing (EventSummary)
import Data.Series.Wec exposing (Wec(..))


wec_2025 : List EventSummary
wec_2025 =
    List.map toEventSummary_Wec_2025
        [ Qatar_1812km
        , Imola_6h
        , Spa_6h
        , LeMans_24h
        , SãoPaulo_6h
        ]


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
            , season = 2025
            , date = "2025-03-01"
            , jsonPath = jsonPath
            }

        Imola_6h ->
            { id = id
            , name = "6 Hours of Imola"
            , season = 2025
            , date = "2025-04-20"
            , jsonPath = jsonPath
            }

        Spa_6h ->
            { id = id
            , name = "6 Hours of Spa"
            , season = 2025
            , date = "2025-05-10"
            , jsonPath = jsonPath
            }

        LeMans_24h ->
            { id = id
            , name = "24 Hours of Le Mans"
            , season = 2025
            , date = "2025-06-14"
            , jsonPath = jsonPath
            }

        SãoPaulo_6h ->
            { id = id
            , name = "6 Hours of São Paulo"
            , season = 2025
            , date = "2025-07-13"
            , jsonPath = jsonPath
            }

        _ ->
            { id = id
            , name = "Qatar 1812km"
            , season = 2025
            , date = "2025-03-01"
            , jsonPath = jsonPath
            }


carImageFileName_2025 : String -> Maybe String
carImageFileName_2025 carNumber =
    case carNumber of
        "4" ->
            Just "/98370/2025-lm-4-porsche-963-droite_6847e4.png"

        "5" ->
            Just "/91620/2_66467b.png"

        "6" ->
            Just "/91621/2_e70d15.png"

        "7" ->
            Just "/98374/2025-lm-7-toyota-gr010-droite_47e4ea.png"

        "007" ->
            Just "/91618/2_9d9bab.png"

        "8" ->
            Just "/91623/2_9f9d8f.png"

        "9" ->
            Just "/98378/2025-lm-9-oreca-07-droite_847e5d.png"

        "009" ->
            Just "/91619/2_be0379.png"

        "10" ->
            Just "/91636/2_5767b9.png"

        "11" ->
            Just "/98379/2025-lm-11-oreca-07-droite_7e5f6c.png"

        "12" ->
            Just "/91624/2_567b99.png"

        "13" ->
            Just "/98395/2025-lm-13-corvette-z06-gt3-r-droite_7eca65.png"

        "15" ->
            Just "/91625/2_9c473f.png"

        "16" ->
            Just "/98380/2025-lm-16-oreca-07-droite_36847e.png"

        "18" ->
            Just "/98381/2025-lm-18-oreca-07-droite_634683.png"

        "20" ->
            Just "/91626/2_167b99.png"

        "21" ->
            Just "/91637/2_d9c8d4.png"

        "22" ->
            Just "/98382/2025-lm-22-oreca-07-droite_63d7ff.png"

        "23" ->
            Just "/98383/2025-lm-23-oreca-07-droite_882684.png"

        "24" ->
            Just "/98384/2025-lm-24-oreca-07-droite_adfcc3.png"

        "25" ->
            Just "/98385/2025-lm-25-oreca-07-droite_09c09b.png"

        "27" ->
            Just "/91638/2_7b99d9.png"

        "28" ->
            Just "/98386/2025-lm-28-oreca-07-droite_6847e6.png"

        "29" ->
            Just "/98387/2025-lm-29-oreca-07-droite_e71e3d.png"

        "31" ->
            Just "/91639/2_67b99d.png"

        "33" ->
            Just "/91641/2_b99d9c.png"

        "34" ->
            Just "/98388/2025-lm-34-oreca-07-droite_7400a2.png"

        "35" ->
            Just "/91627/2_367b99.png"

        "36" ->
            Just "/91628/2_d9d399.png"

        "37" ->
            Just "/98389/2025-lm-37-oreca-07-droite_793684.png"

        "38" ->
            Just "/91629/2_367b99-1.png"

        "43" ->
            Just "/98099/2025-lm-43-oreca-07-droite_442e0c.png"

        "45" ->
            Just "/98391/2025-lm-45-oreca-07-droite_e99b3e.png"

        "46" ->
            Just "/91640/2_b99d9d.png"

        "48" ->
            Just "/98390/2025-lm-48-oreca-07-droite_06847e.png"

        "50" ->
            Just "/91630/2_9d9324.png"

        "51" ->
            Just "/91631/2_b99d9d-1.png"

        "54" ->
            Just "/91642/2_99d9dd.png"

        "57" ->
            Just "/98402/2025-lm-57-ferrari-296-gt3-droite_eda01a.png"

        "59" ->
            Just "/91643/2_df02e2.png"

        "60" ->
            Just "/91645/2_9d9e36.png"

        "61" ->
            Just "/91646/2_267b99.png"

        "63" ->
            Just "/98406/2025-lm-63-mercedes-droite_7edfa4.png"

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

        "90" ->
            Just "/98414/2025-lm-90-porsche-911-gt3-r-droite_d8a36c.png"

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

        "101" ->
            Just "/98060/2025-lm-101-cadillac-droite_4419cc.png"

        "150" ->
            Just "/98417/2025-lm-150-ferrari-296-droite_847ef3.png"

        "183" ->
            Just "/98392/2025-lm-183-oreca-07-droite_86847e.png"

        "193" ->
            Just "/98418/2025-lm-193-ferrari-296-droite_f5858d.png"

        "199" ->
            Just "/98393/2025-lm-199-oreca-07-droite_396847.png"

        "311" ->
            Just "/98061/2025-lm-311-cadillac-droite_684419.png"

        _ ->
            Nothing
