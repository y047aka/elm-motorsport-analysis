module PersonName.Parse exposing (fromUppercasedSurname)

{-| Names read out of strings.

There is no dictionary here — no titles, no particles, no nobility — only the case of a word and where it stands, which is what BibTeX reads a name by.

@docs fromUppercasedSurname

-}

import List.Extra
import PersonName exposing (PersonName)


{-| A name spelled with the surname uppercased, the way a timing feed writes it: `Kamui KOBAYASHI`.

Case, not word position, marks where the surname begins, so a compound surname and a multi-word given name both come out right: `Jose Maria LOPEZ` splits after `Maria`.

Where case says nothing — no uppercase word (`Kamui Kobayashi`), or the first word uppercase (`PJ HYETT`) — the last word is taken as the surname.

    import NonEmpty
    import PersonName exposing (PersonName, given, surname)

    surnames : Maybe PersonName -> List String
    surnames =
        Maybe.andThen surname >> Maybe.map NonEmpty.toList >> Maybe.withDefault []

    givenNames : Maybe PersonName -> List String
    givenNames =
        Maybe.andThen given >> Maybe.map NonEmpty.toList >> Maybe.withDefault []

    surnames (fromUppercasedSurname "Kamui KOBAYASHI")
    --> [ "KOBAYASHI" ]

    givenNames (fromUppercasedSurname "Jose Maria LOPEZ")
    --> [ "Jose", "Maria" ]

    surnames (fromUppercasedSurname "Kelvin VAN DER LINDE")
    --> [ "VAN", "DER", "LINDE" ]

    surnames (fromUppercasedSurname "PJ HYETT")
    --> [ "HYETT" ]

    givenNames (fromUppercasedSurname "Kobayashi")
    --> []

    surnames (fromUppercasedSurname "9")
    --> [ "9" ]

    fromUppercasedSurname ""
    --> Nothing

-}
fromUppercasedSurname : String -> Maybe PersonName
fromUppercasedSurname fullName =
    let
        words =
            String.words fullName
    in
    case List.Extra.splitWhen isUppercaseWord words of
        Just ( [], _ ) ->
            atLastWord words

        Just ( given, surname ) ->
            PersonName.fromParts { given = given, surname = surname }

        Nothing ->
            atLastWord words


{-| Requires letters, so a word of digits or punctuation alone never marks where the surname begins.
-}
isUppercaseWord : String -> Bool
isUppercaseWord word =
    (String.toUpper word /= String.toLower word)
        && (word == String.toUpper word)


atLastWord : List String -> Maybe PersonName
atLastWord words =
    case List.Extra.unconsLast words of
        Just ( last, given ) ->
            PersonName.fromParts { given = given, surname = [ last ] }

        Nothing ->
            Nothing
