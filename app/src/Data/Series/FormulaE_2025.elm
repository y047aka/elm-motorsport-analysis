module Data.Series.FormulaE_2025 exposing (formulaE_2025, toEventSummary_FormulaE_2025)

import Data.Series.FormulaE exposing (EventSummary, FormulaE(..))


formulaE_2025 : List EventSummary
formulaE_2025 =
    List.map toEventSummary_FormulaE_2025
        [ Tokyo ]


toEventSummary_FormulaE_2025 : FormulaE -> EventSummary
toEventSummary_FormulaE_2025 event =
    let
        id =
            case event of
                Tokyo ->
                    "R08_tokyo"

        jsonPath =
            "/static/formula-e/2025/" ++ id ++ ".json"
    in
    case event of
        Tokyo ->
            { id = id
            , name = "Tokyo E-Prix"
            , season = 2025
            , date = "2025-05-17"
            , jsonPath = jsonPath
            }
