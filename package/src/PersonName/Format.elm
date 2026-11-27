module PersonName.Format exposing (Format, Given(..), format)

{-| Names written back out as strings.

A [`Format`](#Format) says how much of the given name is written and what stands between the words. The surname is uppercased word by word, which is how the sport writes it, so `VAN DER LINDE` and `Van Der Linde` come out the same.

@docs Format, Given, format

-}

import NonEmpty exposing (NonEmpty)
import PersonName exposing (PersonName)


{-| How much of the given name is written.

`Initials "."` writes `Kamui` as `K.`: every given name abbreviated to its first character, the argument written after each one. That character comes from `String.left 1`, which cuts a UTF-16 code unit and not a grapheme: a letter written with a separate combining mark loses the mark, and a character outside the basic multilingual plane is cut in half.

-}
type Given
    = Full
    | Initials String
    | Omitted


{-| How a name is written out.

`separator` stands between the words the given name writes, and between the given name and the surname. A part the name does not have, or one written as nothing, takes its separator with it, so a name never starts or ends with one.

-}
type alias Format =
    { given : Given
    , separator : String
    }


{-| Write the name.

    import PersonName exposing (PersonName, fromParts)

    kamui : Maybe PersonName
    kamui =
        fromParts { given = [ "Kamui" ], surname = [ "KOBAYASHI" ] }

    lopez : Maybe PersonName
    lopez =
        fromParts { given = [ "Jose", "Maria" ], surname = [ "LOPEZ" ] }

    linde : Maybe PersonName
    linde =
        fromParts { given = [ "Kelvin" ], surname = [ "VAN", "DER", "LINDE" ] }

    Maybe.map (format { given = Full, separator = " " }) kamui
    --> Just "Kamui KOBAYASHI"

    Maybe.map (format { given = Full, separator = " " }) lopez
    --> Just "Jose Maria LOPEZ"

    Maybe.map (format { given = Initials ".", separator = "" }) kamui
    --> Just "K.KOBAYASHI"

    Maybe.map (format { given = Initials ".", separator = "" }) lopez
    --> Just "J.M.LOPEZ"

    Maybe.map (format { given = Initials ".", separator = " " }) linde
    --> Just "K. VAN DER LINDE"

    Maybe.map (format { given = Omitted, separator = " " }) linde
    --> Just "VAN DER LINDE"

    Maybe.map (format { given = Omitted, separator = " " }) kamui
    --> Just "KOBAYASHI"

    noGiven : Maybe PersonName
    noGiven =
        fromParts { given = [], surname = [ "Kobayashi" ] }

    noSurname : Maybe PersonName
    noSurname =
        fromParts { given = [ "Kamui" ], surname = [] }

    Maybe.map (format { given = Initials ".", separator = "" }) noGiven
    --> Just "KOBAYASHI"

    Maybe.map (format { given = Full, separator = " " }) noSurname
    --> Just "Kamui"

-}
format : Format -> PersonName -> String
format style name =
    [ Maybe.andThen (writeGiven style) (PersonName.given name)
    , Maybe.map writeSurname (PersonName.surname name)
    ]
        |> List.filterMap identity
        |> String.join style.separator


{-| `Omitted` leaves no part to write, which is why this returns a `Maybe` and `writeSurname` does not.
-}
writeGiven : Format -> NonEmpty String -> Maybe String
writeGiven style givenNames =
    let
        words =
            NonEmpty.toList givenNames
    in
    case style.given of
        Full ->
            Just (String.join style.separator words)

        Initials suffix ->
            words
                |> List.map (\word -> String.left 1 word ++ suffix)
                |> String.join style.separator
                |> Just

        Omitted ->
            Nothing


{-| The surname is written as one word whatever words the name has for it, so `separator` never falls inside one.
-}
writeSurname : NonEmpty String -> String
writeSurname surnameWords =
    surnameWords
        |> NonEmpty.toList
        |> List.map String.toUpper
        |> String.join " "
