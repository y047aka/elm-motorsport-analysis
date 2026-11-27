module PersonName exposing (PersonName, fromParts, given, surname)

{-| A person's name, held as the shape the name has: a given name and a surname, or only one of them.

Nothing here reads a name out of a string or writes one back: that is `PersonName.Parse` and `PersonName.Format`.

Nothing here knows the sport either: these modules import `elm/core` and `elm-community/list-extra` and nothing else, so they can be published on their own.

@docs PersonName, fromParts, given, surname

-}

import NonEmpty exposing (NonEmpty)


{-| No part is empty and no word carries outer whitespace, which is what [`fromParts`](#fromParts) guarantees.
-}
type PersonName
    = FullName { given : NonEmpty String, surname : NonEmpty String }
    | GivenOnly (NonEmpty String)
    | SurnameOnly (NonEmpty String)


{-| The parts of a name, into the name that has them.

Every word is trimmed and the words left blank are dropped. What is left decides the shape: both parts make a `FullName`, one part makes a name of that part alone, and nothing surviving at all is `Nothing`.

    import NonEmpty exposing (NonEmpty)

    fromParts { given = [ "Kamui" ], surname = [ "Kobayashi" ] }
        |> Maybe.andThen surname
        |> Maybe.map NonEmpty.toList
    --> Just [ "Kobayashi" ]

    fromParts { given = [ "Kamui", "  " ], surname = [ "Kobayashi" ] }
        |> Maybe.andThen given
        |> Maybe.map NonEmpty.toList
    --> Just [ "Kamui" ]

    fromParts { given = [ "Kamui " ], surname = [ "Kobayashi" ] }
        |> Maybe.andThen given
        |> Maybe.map NonEmpty.toList
    --> Just [ "Kamui" ]

    fromParts { given = [ "Kamui" ], surname = [ " van " ] }
        |> Maybe.andThen surname
        |> Maybe.map NonEmpty.toList
    --> Just [ "van" ]

    fromParts { given = [], surname = [ "Kobayashi" ] }
        |> Maybe.andThen given
    --> Nothing

    fromParts { given = [ "Kamui" ], surname = [ "" ] }
        |> Maybe.andThen surname
    --> Nothing

    fromParts { given = [], surname = [] }
    --> Nothing

-}
fromParts : { given : List String, surname : List String } -> Maybe PersonName
fromParts parts =
    let
        kept : List String -> Maybe (NonEmpty String)
        kept =
            List.map String.trim >> List.filter (String.isEmpty >> not) >> NonEmpty.fromList
    in
    case ( kept parts.given, kept parts.surname ) of
        ( Just givenNames, Just surnameWords ) ->
            Just (FullName { given = givenNames, surname = surnameWords })

        ( Just givenNames, Nothing ) ->
            Just (GivenOnly givenNames)

        ( Nothing, Just surnameWords ) ->
            Just (SurnameOnly surnameWords)

        ( Nothing, Nothing ) ->
            Nothing


{-| The given names, when the name has any. A name given several of them keeps them all, in the order it spells them.

    import NonEmpty exposing (NonEmpty)

    fromParts { given = [ "Jose", "Maria" ], surname = [ "LOPEZ" ] }
        |> Maybe.andThen given
        |> Maybe.map NonEmpty.toList
    --> Just [ "Jose", "Maria" ]

    fromParts { given = [], surname = [ "KOBAYASHI" ] }
        |> Maybe.andThen given
    --> Nothing

-}
given : PersonName -> Maybe (NonEmpty String)
given name =
    case name of
        FullName parts ->
            Just parts.given

        GivenOnly givenNames ->
            Just givenNames

        SurnameOnly _ ->
            Nothing


{-| The surname, when the name has one. A compound surname is several words.

    import NonEmpty exposing (NonEmpty)

    fromParts { given = [ "Kelvin" ], surname = [ "VAN", "DER", "LINDE" ] }
        |> Maybe.andThen surname
        |> Maybe.map NonEmpty.toList
    --> Just [ "VAN", "DER", "LINDE" ]

    fromParts { given = [ "Kamui" ], surname = [] }
        |> Maybe.andThen surname
    --> Nothing

-}
surname : PersonName -> Maybe (NonEmpty String)
surname name =
    case name of
        FullName parts ->
            Just parts.surname

        SurnameOnly surnameWords ->
            Just surnameWords

        GivenOnly _ ->
            Nothing
