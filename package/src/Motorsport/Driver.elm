module Motorsport.Driver exposing
    ( Driver, fromName
    , isSame, changeBetween
    , fullName, initialsAndSurname, surnameOnly, handover
    )

{-| A driver, and the ways their name is written.

Every spelling here uppercases the surname (`PersonName.Format`).

@docs Driver, fromName
@docs isSame, changeBetween
@docs fullName, initialsAndSurname, surnameOnly, handover

-}

import PersonName exposing (PersonName)
import PersonName.Format as Format


{-| A driver, identified by the person's name.
-}
type Driver
    = Driver PersonName


{-| The driver named by a person's name.
-}
fromName : PersonName -> Driver
fromName =
    Driver


{-| Whether two drivers are the same person.

Namesakes are indistinguishable, and the name is compared as written, so one person spelled two ways is two drivers: the timing files hold both `Antonio FELIX DA COSTA` and `António FÉLIX DA COSTA`.

    import PersonName.Parse exposing (fromUppercasedSurname)

    sameName : String -> String -> Maybe Bool
    sameName a b =
        Maybe.map2 (\one another -> isSame (fromName one) (fromName another))
            (fromUppercasedSurname a)
            (fromUppercasedSurname b)

    sameName "Kamui KOBAYASHI" "Kamui KOBAYASHI"
    --> Just True

    sameName "Kamui KOBAYASHI" "Nyck DE VRIES"
    --> Just False

-}
isSame : Driver -> Driver -> Bool
isSame a b =
    a == b


{-| The handover of a car between two drivers: the pair, when they are not the same person.

    import PersonName.Parse exposing (fromUppercasedSurname)

    change : String -> String -> Maybe String
    change a b =
        Maybe.map2
            (\handedOver tookOver ->
                Maybe.map (\( before, after ) -> initialsAndSurname before ++ " → " ++ initialsAndSurname after) (changeBetween handedOver tookOver)
            )
            (fromUppercasedSurname a |> Maybe.map fromName)
            (fromUppercasedSurname b |> Maybe.map fromName)
            |> Maybe.withDefault Nothing

    change "Sebastian BUEMI" "Sebastian BUEMI"
    --> Nothing

    change "Sebastian BUEMI" "Kamui KOBAYASHI"
    --> Just "S.BUEMI → K.KOBAYASHI"

-}
changeBetween : Driver -> Driver -> Maybe ( Driver, Driver )
changeBetween handedOver tookOver =
    if isSame handedOver tookOver then
        Nothing

    else
        Just ( handedOver, tookOver )


{-| The whole name.

    import PersonName.Parse exposing (fromUppercasedSurname)

    shown : String -> Maybe String
    shown =
        fromUppercasedSurname >> Maybe.map (fromName >> fullName)

    shown "Kamui Kobayashi"
    --> Just "Kamui KOBAYASHI"

    shown "Jose Maria LOPEZ"
    --> Just "Jose Maria LOPEZ"

    shown "Kelvin VAN DER LINDE"
    --> Just "Kelvin VAN DER LINDE"

-}
fullName : Driver -> String
fullName (Driver person) =
    Format.format { given = Format.Full, separator = " " } person


{-| Each given name an initial, nothing between them.

    import PersonName.Parse exposing (fromUppercasedSurname)

    shown : String -> Maybe String
    shown =
        fromUppercasedSurname >> Maybe.map (fromName >> initialsAndSurname)

    shown "Kamui Kobayashi"
    --> Just "K.KOBAYASHI"

    shown "Jose Maria LOPEZ"
    --> Just "J.M.LOPEZ"

    shown "Kelvin VAN DER LINDE"
    --> Just "K.VAN DER LINDE"

    shown "Kobayashi"
    --> Just "KOBAYASHI"

-}
initialsAndSurname : Driver -> String
initialsAndSurname (Driver person) =
    Format.format { given = Format.Initials ".", separator = "" } person


{-| Nothing but the surname.

    import PersonName.Parse exposing (fromUppercasedSurname)

    shown : String -> Maybe String
    shown =
        fromUppercasedSurname >> Maybe.map (fromName >> surnameOnly)

    shown "Kamui Kobayashi"
    --> Just "KOBAYASHI"

    shown "Kelvin VAN DER LINDE"
    --> Just "VAN DER LINDE"

-}
surnameOnly : Driver -> String
surnameOnly (Driver person) =
    Format.format { given = Format.Omitted, separator = " " } person


{-| A driver change, spelled out: who handed the car over, and who took it on.

    import PersonName.Parse exposing (fromUppercasedSurname)

    change : String -> String -> Maybe String
    change handedOver tookOver =
        Maybe.map2 handover
            (fromUppercasedSurname handedOver |> Maybe.map fromName)
            (fromUppercasedSurname tookOver |> Maybe.map fromName)

    change "Sebastian BUEMI" "Kamui Kobayashi"
    --> Just "S.BUEMI → K.KOBAYASHI"

-}
handover : Driver -> Driver -> String
handover handedOver tookOver =
    initialsAndSurname handedOver ++ " → " ++ initialsAndSurname tookOver
