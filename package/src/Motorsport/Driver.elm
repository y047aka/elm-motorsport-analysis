module Motorsport.Driver exposing (Driver, toDisplayName, toSurnameDisplay)

{-|

@docs Driver, toDisplayName, toSurnameDisplay

-}


type alias Driver =
    { name : String }


{-| Keep the first name as-is and uppercase the surname (second word onward).

    toDisplayName "Kamui Kobayashi"
    --> "Kamui KOBAYASHI"

    toDisplayName "Kobayashi"
    --> "Kobayashi"

-}
toDisplayName : String -> String
toDisplayName fullName =
    case String.words fullName of
        first :: rest ->
            first :: (rest |> List.map String.toUpper) |> String.join " "

        [] ->
            fullName


{-| Drop the first name and show only the uppercased surname (second word onward).
Intended for narrow lists.

    toSurnameDisplay "Kamui Kobayashi"
    --> "KOBAYASHI"

-}
toSurnameDisplay : String -> String
toSurnameDisplay fullName =
    case String.words fullName of
        _ :: rest ->
            rest |> List.map String.toUpper |> String.join " "

        [] ->
            fullName
