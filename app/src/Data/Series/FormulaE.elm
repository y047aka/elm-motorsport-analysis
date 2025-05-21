module Data.Series.FormulaE exposing
    ( FormulaE(..), fromString
    , EventSummary
    )

{-| FormulaE series

@docs FormulaE, fromString
@docs EventSummary

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


type alias EventSummary =
    { id : String
    , name : String
    , season : Int
    , date : String
    , jsonPath : String
    }
