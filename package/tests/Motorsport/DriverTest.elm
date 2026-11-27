module Motorsport.DriverTest exposing (suite)

import Expect
import Motorsport.Driver as Driver
import Motorsport.TestHelpers.Driver exposing (driverNamed)
import Test exposing (Test, describe, test)


{-| One driver's name as the timing files spell it, and the three ways it reaches the screen.

The names are the ones the parse has the least to go on: a compound surname, which the uppercase marker has to carry across several words at once, and `PJ HYETT`, where case says nothing and the last word is taken as the surname. `Kobayashi` is a name with no given name in it, so all three spellings come out the same.

-}
type alias Spelled =
    { name : String, fullName : String, initials : String, surname : String }


spelled : List Spelled
spelled =
    [ { name = "Kelvin VAN DER LINDE", fullName = "Kelvin VAN DER LINDE", initials = "K.VAN DER LINDE", surname = "VAN DER LINDE" }
    , { name = "Sheldon VAN DER LINDE", fullName = "Sheldon VAN DER LINDE", initials = "S.VAN DER LINDE", surname = "VAN DER LINDE" }
    , { name = "Alessandro PIER GUIDI", fullName = "Alessandro PIER GUIDI", initials = "A.PIER GUIDI", surname = "PIER GUIDI" }
    , { name = "David HEINEMEIER HANSSON", fullName = "David HEINEMEIER HANSSON", initials = "D.HEINEMEIER HANSSON", surname = "HEINEMEIER HANSSON" }
    , { name = "Paul DI RESTA", fullName = "Paul DI RESTA", initials = "P.DI RESTA", surname = "DI RESTA" }
    , { name = "Antonio FELIX DA COSTA", fullName = "Antonio FELIX DA COSTA", initials = "A.FELIX DA COSTA", surname = "FELIX DA COSTA" }
    , { name = "Larry TEN VOORDE", fullName = "Larry TEN VOORDE", initials = "L.TEN VOORDE", surname = "TEN VOORDE" }
    , { name = "Job VAN UITERT", fullName = "Job VAN UITERT", initials = "J.VAN UITERT", surname = "VAN UITERT" }
    , { name = "Ahmad AL HARTHY", fullName = "Ahmad AL HARTHY", initials = "A.AL HARTHY", surname = "AL HARTHY" }
    , { name = "PJ HYETT", fullName = "PJ HYETT", initials = "P.HYETT", surname = "HYETT" }
    , { name = "Kamui KOBAYASHI", fullName = "Kamui KOBAYASHI", initials = "K.KOBAYASHI", surname = "KOBAYASHI" }
    , { name = "Kobayashi", fullName = "KOBAYASHI", initials = "KOBAYASHI", surname = "KOBAYASHI" }
    ]


spellings : Spelled -> Test
spellings entry =
    test entry.name <|
        \_ ->
            let
                driver =
                    driverNamed entry.name
            in
            Expect.equal ( entry.fullName, entry.initials, entry.surname )
                ( Driver.fullName driver, Driver.initialsAndSurname driver, Driver.surnameOnly driver )


suite : Test
suite =
    describe "Motorsport.Driver"
        [ describe "the three spellings" (List.map spellings spelled)
        , test "a driver change spells both in the short form" <|
            \_ ->
                Expect.equal "S.BUEMI → K.KOBAYASHI" <|
                    Driver.handover (driverNamed "Sebastian BUEMI") (driverNamed "Kamui KOBAYASHI")

        -- The same person, one season spelled without the accents and the next with them.
        , test "one person spelled two ways is two drivers" <|
            \_ ->
                Expect.equal False <|
                    Driver.isSame (driverNamed "Antonio FELIX DA COSTA")
                        (driverNamed "António FÉLIX DA COSTA")
        ]
