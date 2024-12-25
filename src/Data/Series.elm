module Data.Series exposing (toCsvFileName, toRoutePath, toString, wec_2024)

import Route.Path exposing (Path(..))


type Wec
    = LeMans_24
    | Fuji_6
    | Bahrain_8


wec_2024 : List Wec
wec_2024 =
    [ LeMans_24
    , Fuji_6
    , Bahrain_8
    ]


toString : Wec -> String
toString event =
    case event of
        LeMans_24 ->
            "24 Hours of Le Mans"

        Fuji_6 ->
            "6 Hours of Fuji"

        Bahrain_8 ->
            "8 Hours of Bahrain"


toCsvFileName : Wec -> String
toCsvFileName event =
    case event of
        LeMans_24 ->
            "23_Analysis_Race_Hour 24"

        Fuji_6 ->
            "23_Analysis_Race_Hour 6"

        Bahrain_8 ->
            "23_Analysis_Race_Hour 8"


toRoutePath : Wec -> Path
toRoutePath event =
    Wec_Id_ { id = toCsvFileName event }
