module Motorsport.Wec.Circuit.MapTest exposing (tests)

{-| A circuit map's record, read: the figures a drawing is laid from, refused where its lines stand out of order round the lap.
-}

import Expect
import Json.Decode as Decode
import Length exposing (Length)
import Motorsport.Wec.Circuit.LeMans.Layout as LeMansLayout
import Motorsport.Wec.Circuit.Map as Map
import Test exposing (Test, describe, test)


record : { lap : Float, lines : List ( String, Float ) } -> String
record { lap, lines } =
    let
        line ( name, metres ) =
            "\"" ++ name ++ "\": {\"metres\": " ++ String.fromFloat metres ++ "}"
    in
    "{\"lengths\": {\"centerline\": {\"metres\": " ++ String.fromFloat lap ++ "}}, \"lines\": {" ++ String.join ", " (List.map line lines) ++ "}}"


intermediates : Float -> Float -> Float -> Result Decode.Error Map.Intermediates
intermediates lap i1 i2 =
    Decode.decodeString Map.intermediatesDecoder (record { lap = lap, lines = [ ( "intermediate1", i1 ), ( "intermediate2", i2 ) ] })


tests : Test
tests =
    describe "Motorsport.Wec.Circuit.Map"
        [ test "a record whose lines stand in order is read whole" <|
            \_ ->
                intermediates 5513 1311 3568
                    |> Expect.equal
                        (Ok
                            { centreline = Length.meters 5513
                            , intermediate1 = Length.meters 1311
                            , intermediate2 = Length.meters 3568
                            }
                        )
        , test "a record whose second line stands before its first is refused" <|
            \_ ->
                intermediates 5513 3568 1311
                    |> Expect.err
        , test "a record with a line past the end of its lap is refused" <|
            \_ ->
                intermediates 5513 1311 5600
                    |> Expect.err
        , test "Le Mans's record is refused where any of its six lines stands out of order" <|
            \_ ->
                record
                    { lap = 13625.7
                    , lines =
                        [ ( "intermediate1", 1900.7 )
                        , ( "intermediate2", 7672.13 )
                        , ( "porscheIn", 12507.09 )
                        , ( "porscheOut", 11475.77 )
                        , ( "fordIn", 13246.35 )
                        , ( "fordOut", 13470.88 )
                        ]
                    }
                    |> Decode.decodeString LeMansLayout.mapDecoder
                    |> Expect.err
        ]
