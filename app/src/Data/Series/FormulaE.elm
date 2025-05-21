module Data.Series.FormulaE exposing (FormulaE(..), fromString)

{-| FormulaE series

@docs FormulaE, fromString

-}


type FormulaE
    = Tokyo


fromString : String -> Maybe FormulaE
fromString string =
    case string of
        "R08_tokyo" ->
            Just Tokyo

        _ ->
            Nothing
