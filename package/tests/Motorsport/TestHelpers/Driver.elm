module Motorsport.TestHelpers.Driver exposing (driverNamed)

{-|

@docs driverNamed

-}

import Motorsport.Driver as Driver exposing (Driver)
import PersonName.Parse exposing (fromUppercasedSurname)


{-| A driver named by a string, the way the source data spells it. Fails the test when the string has no surname in it.
-}
driverNamed : String -> Driver
driverNamed fullName =
    case fromUppercasedSurname fullName of
        Just person ->
            Driver.fromName person

        Nothing ->
            Debug.todo ("no driver named " ++ fullName)
