module A2uiTest exposing (suite)

import A2ui exposing (Message(..), Value(..))
import Array
import Dict
import Expect
import Json.Decode as Decode
import Json.Encode as Encode
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "A2ui"
        [ wire
        , dataModel
        , building
        , templates
        ]


object : List ( String, Value ) -> Value
object =
    Dict.fromList >> JObject


component : String -> String -> List ( String, Value ) -> A2ui.Component
component id name properties =
    { id = id, component = name, properties = Dict.fromList properties }


bound : String -> Value
bound path =
    object [ ( "@path", JString path ) ]


roundTrip : Message -> Result Decode.Error String
roundTrip message =
    Encode.encode 0 (A2ui.encode message)
        |> Decode.decodeString A2ui.decoder
        |> Result.map (A2ui.encode >> Encode.encode 0)


messages : List Message
messages =
    [ CreateSurface
        { surfaceId = "inline"
        , catalogId = "urn:test"
        , components = [ component "root" "Text" [ ( "text", bound "/greeting" ) ] ]
        , dataModel = Just (object [ ( "greeting", JString "hi" ) ])
        }
    , CreateSurface { surfaceId = "s", catalogId = "urn:test", components = [], dataModel = Nothing }
    , UpdateComponents { surfaceId = "s", components = [ component "root" "Text" [ ( "text", bound "/greeting" ) ] ] }
    , UpdateDataModel { surfaceId = "s", path = "/greeting", value = JString "hello" }
    , DeleteSurface { surfaceId = "s" }
    ]


wire : Test
wire =
    describe "the wire"
        [ test "every message reads back as it was written" <|
            \_ ->
                messages
                    |> List.map roundTrip
                    |> Expect.equal (List.map (A2ui.encode >> Encode.encode 0 >> Ok) messages)
        , test "a component's properties sit beside its id, as v1.0 lays it flat" <|
            \_ ->
                """{"version":"1.0","updateComponents":{"surfaceId":"s","components":[{"id":"root","component":"Text","text":"hi"}]}}"""
                    |> Decode.decodeString A2ui.decoder
                    |> Result.map
                        (\m ->
                            case m of
                                UpdateComponents { components } ->
                                    List.map (\c -> ( c.id, c.component, Dict.toList c.properties )) components

                                _ ->
                                    []
                        )
                    |> Expect.equal (Ok [ ( "root", "Text", [ ( "text", JString "hi" ) ] ) ])
        , test "a message carrying two is refused, not read as the first" <|
            \_ ->
                """{"version":"1.0","deleteSurface":{"surfaceId":"s"},"createSurface":{"surfaceId":"t"}}"""
                    |> Decode.decodeString A2ui.decoder
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "an optional field of the wrong shape is refused, not read as absent" <|
            \_ ->
                """{"version":"1.0","createSurface":{"surfaceId":"s","catalogId":7}}"""
                    |> Decode.decodeString A2ui.decoder
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "another version is refused, not read as this one" <|
            \_ ->
                """{"version":"v0.9","deleteSurface":{"surfaceId":"s"}}"""
                    |> Decode.decodeString A2ui.decoder
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        ]


{-| The surface `s` with a `root` that reads each of `paths`, after `updates`.
-}
readAfter : List ( String, Value ) -> List String -> Result String (List (Maybe Value))
readAfter updates paths =
    let
        reader =
            component "root" "Probe" (List.map (\p -> ( p, bound p )) paths)
    in
    (CreateSurface { surfaceId = "s", catalogId = "", components = [], dataModel = Nothing }
        :: UpdateComponents { surfaceId = "s", components = [ reader ] }
        :: List.map (\( path, value ) -> UpdateDataModel { surfaceId = "s", path = path, value = value }) updates
    )
        |> A2ui.surface "s"
        |> Result.map (\s -> List.map (A2ui.read s A2ui.root reader) paths)


dataModel : Test
dataModel =
    describe "the data model"
        [ test "a pointer makes what leads to it" <|
            \_ ->
                readAfter [ ( "/a/b", JString "x" ), ( "/a/c", JNumber 1 ) ] [ "/a/b", "/a/c", "/a/d" ]
                    |> Expect.equal (Ok [ Just (JString "x"), Just (JNumber 1), Nothing ])
        , test "the index past an array's end appends" <|
            \_ ->
                readAfter [ ( "/list", JArray Array.empty ), ( "/list/0", JString "first" ), ( "/list/1", JString "second" ) ]
                    [ "/list/0", "/list/1" ]
                    |> Expect.equal (Ok [ Just (JString "first"), Just (JString "second") ])
        , test "null deletes the key" <|
            \_ ->
                readAfter [ ( "/a/b", JString "x" ), ( "/a/b", JNull ) ] [ "/a/b" ]
                    |> Expect.equal (Ok [ Nothing ])
        , test "a key holding a slash is spelled ~1" <|
            \_ ->
                readAfter [ ( "/a~1b", JString "x" ) ] [ "/a~1b" ]
                    |> Expect.equal (Ok [ Just (JString "x") ])
        , test "an empty segment is the empty key, not skipped" <|
            \_ ->
                readAfter [ ( "/a//b", JString "x" ) ] [ "/a//b", "/a/b" ]
                    |> Expect.equal (Ok [ Just (JString "x"), Nothing ])
        , test "a null is written under as if it were not there" <|
            \_ ->
                readAfter [ ( "/a", JNull ), ( "/a/b", JString "x" ) ] [ "/a/b" ]
                    |> Expect.equal (Ok [ Just (JString "x") ])
        , test "an array is not written at a key, nor past the index after its end" <|
            \_ ->
                [ readAfter [ ( "/list", JArray Array.empty ), ( "/list/name", JString "x" ) ] []
                , readAfter [ ( "/list", JArray Array.empty ), ( "/list/1", JString "x" ) ] []
                , readAfter [ ( "/text", JString "t" ), ( "/text/a", JString "x" ) ] []
                ]
                    |> List.map Result.toMaybe
                    |> Expect.equal [ Nothing, Nothing, Nothing ]
        ]


building : Test
building =
    describe "A2ui.surface"
        [ test "an update before the surface is created is an error" <|
            \_ ->
                A2ui.surface "s" [ UpdateDataModel { surfaceId = "s", path = "/", value = JNull } ]
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "a surface with no root is an error" <|
            \_ ->
                A2ui.surface "s" [ CreateSurface { surfaceId = "s", catalogId = "", components = [], dataModel = Nothing } ]
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        , test "another surface's messages are passed over" <|
            \_ ->
                A2ui.surface "s"
                    [ CreateSurface { surfaceId = "s", catalogId = "", components = [], dataModel = Nothing }
                    , UpdateComponents { surfaceId = "other", components = [] }
                    , UpdateComponents { surfaceId = "s", components = [ component "root" "Text" [] ] }
                    ]
                    |> Result.map (.components >> Dict.keys)
                    |> Expect.equal (Ok [ "root" ])
        , test "one createSurface can carry the components and the data they read" <|
            \_ ->
                A2ui.surface "inline" messages
                    |> Result.map
                        (\s ->
                            Dict.get "root" s.components
                                |> Maybe.andThen (\c -> A2ui.read s A2ui.root c "text")
                        )
                    |> Expect.equal (Ok (Just (JString "hi")))
        , test "a deleted surface is gone" <|
            \_ ->
                A2ui.surface "s" messages
                    |> Result.toMaybe
                    |> Expect.equal Nothing
        ]


templates : Test
templates =
    let
        list =
            component "root" "List" [ ( "children", object [ ( "path", JString "/people" ), ( "componentId", JString "row" ) ] ) ]

        row =
            component "row" "Text" [ ( "text", bound "name" ), ( "title", bound "/title" ) ]

        people =
            JArray (Array.fromList [ object [ ( "name", JString "Ann" ) ], object [ ( "name", JString "Bo" ) ] ])
    in
    test "a template's relative path reads its item, and an absolute one the root" <|
        \_ ->
            [ CreateSurface { surfaceId = "s", catalogId = "", components = [], dataModel = Nothing }
            , UpdateComponents { surfaceId = "s", components = [ list, row ] }
            , UpdateDataModel { surfaceId = "s", path = "/", value = object [ ( "people", people ), ( "title", JString "T" ) ] }
            ]
                |> A2ui.surface "s"
                |> Result.map
                    (\s ->
                        case A2ui.children list "children" of
                            Just (A2ui.Template template) ->
                                A2ui.items s A2ui.root template.path
                                    |> List.map (\scope -> ( A2ui.read s scope row "text", A2ui.read s scope row "title" ))

                            _ ->
                                []
                    )
                |> Expect.equal
                    (Ok
                        [ ( Just (JString "Ann"), Just (JString "T") )
                        , ( Just (JString "Bo"), Just (JString "T") )
                        ]
                    )
