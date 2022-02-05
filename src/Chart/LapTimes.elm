module Chart.LapTimes exposing (view)

import Css exposing (..)
import Data.LapTime as LapTime exposing (toString)
import Data.LapTimes exposing (Car, Lap)
import Html.Styled as Html exposing (Html, div, table, tbody, td, text, th, thead, tr)
import Html.Styled.Attributes exposing (colspan, css)
import List.Split


view : List Car -> Html msg
view cars =
    let
        tableHeader =
            thead []
                [ tr []
                    [ th [] [ text "No." ]
                    , th [] [ text "Driver" ]
                    ]
                ]

        tableBody { carNumber, driver, laps } =
            tbody []
                [ tr []
                    [ td [] [ text carNumber ]
                    , td [] [ text driver.name ]
                    ]
                , tr []
                    [ td [ colspan 2 ] [ lapsTable laps ] ]
                ]
    in
    Html.table [] <| tableHeader :: List.map tableBody cars


lapsTable : List Lap -> Html msg
lapsTable laps =
    div [ css [ displayFlex, property "gap" "50px" ] ] <|
        List.map
            (\splittedLaps ->
                let
                    tableBody =
                        tbody [] <|
                            List.map
                                (\{ lap, time } ->
                                    tr []
                                        [ td [] [ text (String.fromInt lap) ]
                                        , td [] [ text (LapTime.toString time) ]
                                        ]
                                )
                                splittedLaps
                in
                Html.table []
                    [ thead []
                        [ tr []
                            [ th [] [ text "Lap" ]
                            , th [] [ text "Time" ]
                            ]
                        ]
                    , tableBody
                    ]
            )
            (List.Split.chunksOfLeft 20 laps)
