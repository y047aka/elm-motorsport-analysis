module Motorsport.Driver exposing
    ( Driver, fromName, unknown
    , isSame
    , toFullName, toInitialAndSurname, toSurname
    )

{-|

@docs Driver, fromName, unknown
@docs isSame
@docs toFullName, toInitialAndSurname, toSurname

-}

import List.Extra


{-| A driver, identified by the name the source data gives.

The given name and surname are split once, at construction, so display is a
lookup rather than a re-parse.

-}
type Driver
    = Driver Name


type alias Name =
    { given : List String
    , family : List String
    }


{-| Build a driver from a full name as the source data spells it.

The source data uppercases the surname (`Kamui KOBAYASHI`), so case — not word
position — marks where it begins. That matters for the compound surnames and
multi-word given names in WEC entry lists: `Jose Maria LOPEZ` splits after
`Maria`.

Where case says nothing — no uppercase word (`Kamui Kobayashi`), or the first
word uppercase (`PJ HYETT`) — the last word is taken as the surname.

-}
fromName : String -> Driver
fromName fullName =
    let
        tokens =
            String.words fullName
    in
    Driver <|
        case List.Extra.splitWhen isUppercaseToken tokens of
            Just ( given, family ) ->
                if List.isEmpty given then
                    splitAtLastToken tokens

                else
                    { given = given, family = family }

            Nothing ->
                splitAtLastToken tokens


splitAtLastToken : List String -> Name
splitAtLastToken tokens =
    case List.Extra.unconsLast tokens of
        Just ( family, given ) ->
            { given = given, family = [ family ] }

        Nothing ->
            { given = [], family = [] }


{-| Requires letters, so digits and punctuation are never taken for a surname.
-}
isUppercaseToken : String -> Bool
isUppercaseToken token =
    (String.toUpper token /= String.toLower token)
        && (token == String.toUpper token)


{-| Stands in for a driver the source data does not name. Displays as an empty
string.

    toFullName unknown
    --> ""

-}
unknown : Driver
unknown =
    fromName ""


{-| Whether two drivers are the same person. Identity rests on the name alone,
so namesakes are indistinguishable; going through this rather than `==` keeps
that decision in one place.

    isSame (fromName "Kamui KOBAYASHI") (fromName "Kamui KOBAYASHI")
    --> True

    isSame (fromName "Kamui KOBAYASHI") (fromName "Nyck DE VRIES")
    --> False

-}
isSame : Driver -> Driver -> Bool
isSame a b =
    a == b



-- DISPLAY
--
-- Three renderings of one name, longest first, differing only in how much of the
-- given name survives. The surname is always present and always uppercased.


{-| Keep the given name in full.

    toFullName (fromName "Kamui Kobayashi")
    --> "Kamui KOBAYASHI"

    toFullName (fromName "Jose Maria LOPEZ")
    --> "Jose Maria LOPEZ"

    toFullName (fromName "Kobayashi")
    --> "KOBAYASHI"

-}
toFullName : Driver -> String
toFullName (Driver parts) =
    String.join " " (parts.given ++ List.map String.toUpper parts.family)


{-| Abbreviate each given name to an initial. For narrow columns.

    toInitialAndSurname (fromName "Kamui Kobayashi")
    --> "K.KOBAYASHI"

    toInitialAndSurname (fromName "Kelvin VAN DER LINDE")
    --> "K.VAN DER LINDE"

    toInitialAndSurname (fromName "Jose Maria LOPEZ")
    --> "J.M.LOPEZ"

    toInitialAndSurname (fromName "Kobayashi")
    --> "KOBAYASHI"

-}
toInitialAndSurname : Driver -> String
toInitialAndSurname (Driver parts) =
    String.join "." (List.map (String.left 1) parts.given ++ [ surnameOf parts ])


{-| Drop the given name entirely. For the narrowest lists.

    toSurname (fromName "Kamui Kobayashi")
    --> "KOBAYASHI"

    toSurname (fromName "Kelvin VAN DER LINDE")
    --> "VAN DER LINDE"

    toSurname (fromName "PJ HYETT")
    --> "HYETT"

    toSurname (fromName "Kobayashi")
    --> "KOBAYASHI"

-}
toSurname : Driver -> String
toSurname (Driver parts) =
    surnameOf parts


surnameOf : Name -> String
surnameOf parts =
    parts.family
        |> List.map String.toUpper
        |> String.join " "
