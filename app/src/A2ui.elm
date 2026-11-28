module A2ui exposing
    ( Message(..), Component, encode, decoder
    , Value(..), encodeValue
    , Surface, surface
    , Scope, root, read, Children(..), children, items
    )

{-| The part of [A2UI v1.0](https://a2ui.org/specification/v1.0-a2ui/) this app speaks: the four messages a producer sends to build a surface, and the reading of a surface's components against its data model.

Nothing here is the sport's, and nothing here draws: which components exist and what they look like is a catalog's.
What a producer may send is what the spec lets it; what is read back is the subset below.

  - A binding is `{"@path": "<pointer>"}`; a pointer without a leading `/` is relative to the item a template is expanding.
  - `children` is a list of ids or a template, `{"path": ..., "componentId": ...}`.
  - `@call` bindings, the renderer's own functions, `sendDataModel` and per-component catalogs are not read: a component carrying one reads as the literal object it is.

@docs Message, Component, encode, decoder
@docs Value, encodeValue
@docs Surface, surface
@docs Scope, root, read, Children, children, items

-}

import Array exposing (Array)
import Dict exposing (Dict)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode


{-| What a producer sends. `UpdateDataModel` with `JNull` deletes what stands at `path`, as the spec's `"value": null` does.
-}
type Message
    = CreateSurface { surfaceId : String, catalogId : String }
    | UpdateComponents { surfaceId : String, components : List Component }
    | UpdateDataModel { surfaceId : String, path : String, value : Value }
    | DeleteSurface { surfaceId : String }


{-| A component as the wire has it: flat, its properties beside `id` and `component`.
-}
type alias Component =
    { id : String
    , component : String
    , properties : Dict String Value
    }


{-| JSON, held as a tree so that a data model can be written into at a pointer.
-}
type Value
    = JNull
    | JBool Bool
    | JNumber Float
    | JString String
    | JArray (Array Value)
    | JObject (Dict String Value)



-- THE WIRE


version : String
version =
    "1.0"


encode : Message -> Encode.Value
encode message =
    let
        envelope key fields =
            Encode.object [ ( "version", Encode.string version ), ( key, Encode.object fields ) ]
    in
    case message of
        CreateSurface m ->
            envelope "createSurface"
                [ ( "surfaceId", Encode.string m.surfaceId )
                , ( "catalogId", Encode.string m.catalogId )
                ]

        UpdateComponents m ->
            envelope "updateComponents"
                [ ( "surfaceId", Encode.string m.surfaceId )
                , ( "components", Encode.list encodeComponent m.components )
                ]

        UpdateDataModel m ->
            envelope "updateDataModel"
                [ ( "surfaceId", Encode.string m.surfaceId )
                , ( "path", Encode.string m.path )
                , ( "value", encodeValue m.value )
                ]

        DeleteSurface m ->
            envelope "deleteSurface"
                [ ( "surfaceId", Encode.string m.surfaceId ) ]


encodeComponent : Component -> Encode.Value
encodeComponent c =
    Encode.object
        (( "id", Encode.string c.id )
            :: ( "component", Encode.string c.component )
            :: List.map (Tuple.mapSecond encodeValue) (Dict.toList c.properties)
        )


encodeValue : Value -> Encode.Value
encodeValue value =
    case value of
        JNull ->
            Encode.null

        JBool b ->
            Encode.bool b

        JNumber n ->
            Encode.float n

        JString s ->
            Encode.string s

        JArray vs ->
            Encode.array encodeValue vs

        JObject fields ->
            Encode.dict identity encodeValue fields


{-| A message of another version, or carrying no message this module knows, fails rather than being skipped: a surface built without it would be a different surface.

`catalogId` is optional in v1.0; a surface created without one reads as `""`, which no catalog here answers to.

-}
decoder : Decoder Message
decoder =
    Decode.field "version" Decode.string
        |> Decode.andThen
            (\v ->
                if v == version then
                    Decode.oneOf
                        [ Decode.field "createSurface" <|
                            Decode.map2 (\s c -> CreateSurface { surfaceId = s, catalogId = c })
                                (Decode.field "surfaceId" Decode.string)
                                (Decode.oneOf [ Decode.field "catalogId" Decode.string, Decode.succeed "" ])
                        , Decode.field "updateComponents" <|
                            Decode.map2 (\s cs -> UpdateComponents { surfaceId = s, components = cs })
                                (Decode.field "surfaceId" Decode.string)
                                (Decode.field "components" (Decode.list componentDecoder))
                        , Decode.field "updateDataModel" <|
                            Decode.map3 (\s p val -> UpdateDataModel { surfaceId = s, path = p, value = val })
                                (Decode.field "surfaceId" Decode.string)
                                (Decode.oneOf [ Decode.field "path" Decode.string, Decode.succeed "/" ])
                                (Decode.field "value" valueDecoder)
                        , Decode.field "deleteSurface" <|
                            Decode.map (\s -> DeleteSurface { surfaceId = s })
                                (Decode.field "surfaceId" Decode.string)
                        ]

                else
                    Decode.fail ("A2UI version " ++ v ++ " is not " ++ version)
            )


componentDecoder : Decoder Component
componentDecoder =
    Decode.map3 Component
        (Decode.field "id" Decode.string)
        (Decode.field "component" Decode.string)
        (Decode.dict valueDecoder
            |> Decode.map (Dict.remove "id" >> Dict.remove "component")
        )


valueDecoder : Decoder Value
valueDecoder =
    Decode.oneOf
        [ Decode.null JNull
        , Decode.map JBool Decode.bool
        , Decode.map JNumber Decode.float
        , Decode.map JString Decode.string
        , Decode.map JArray (Decode.array (Decode.lazy (\_ -> valueDecoder)))
        , Decode.map JObject (Decode.dict (Decode.lazy (\_ -> valueDecoder)))
        ]



-- THE SURFACE


{-| A surface as the messages have left it. One component's id is `root`.
-}
type alias Surface =
    { surfaceId : String
    , catalogId : String
    , components : Dict String Component
    , dataModel : Value
    }


{-| The surface `surfaceId` names, built by applying the messages in order; the messages for other surfaces are passed over.

A surface updated before it is created, created twice, or left without a `root` is an error, and so is one deleted and not created again.

-}
surface : String -> List Message -> Result String Surface
surface surfaceId messages =
    List.foldl (\message -> Result.andThen (apply surfaceId message)) (Ok Nothing) messages
        |> Result.andThen
            (\built ->
                case built of
                    Nothing ->
                        Err ("no surface " ++ surfaceId)

                    Just s ->
                        if Dict.member "root" s.components then
                            Ok s

                        else
                            Err ("surface " ++ surfaceId ++ " has no root")
            )


apply : String -> Message -> Maybe Surface -> Result String (Maybe Surface)
apply surfaceId message current =
    let
        existing id f =
            if id /= surfaceId then
                Ok current

            else
                case current of
                    Just s ->
                        Ok (Just (f s))

                    Nothing ->
                        Err ("surface " ++ id ++ " was updated before it was created")
    in
    case message of
        CreateSurface m ->
            if m.surfaceId /= surfaceId then
                Ok current

            else if current /= Nothing then
                Err ("surface " ++ m.surfaceId ++ " was created twice")

            else
                Ok (Just { surfaceId = m.surfaceId, catalogId = m.catalogId, components = Dict.empty, dataModel = JObject Dict.empty })

        UpdateComponents m ->
            existing m.surfaceId
                (\s -> { s | components = List.foldl (\c -> Dict.insert c.id c) s.components m.components })

        UpdateDataModel m ->
            existing m.surfaceId
                (\s -> { s | dataModel = setAt (pointer m.path) m.value s.dataModel })

        DeleteSurface m ->
            if m.surfaceId == surfaceId then
                Ok Nothing

            else
                Ok current



-- POINTERS


{-| RFC 6901, except that `/` alone is the root, as A2UI's default path is.
-}
pointer : String -> List String
pointer path =
    path
        |> String.split "/"
        |> List.filter (not << String.isEmpty)
        |> List.map (String.replace "~1" "/" >> String.replace "~0" "~")


getAt : List String -> Value -> Maybe Value
getAt segments value =
    case segments of
        [] ->
            Just value

        segment :: rest ->
            case value of
                JObject fields ->
                    Dict.get segment fields |> Maybe.andThen (getAt rest)

                JArray elements ->
                    String.toInt segment
                        |> Maybe.andThen (\i -> Array.get i elements)
                        |> Maybe.andThen (getAt rest)

                _ ->
                    Nothing


{-| What stands at the pointer is replaced, and what leads to it is made where it is missing. `JNull` removes the key; at an array's index it leaves a null, which keeps the indices after it.
-}
setAt : List String -> Value -> Value -> Value
setAt segments new value =
    case segments of
        [] ->
            if new == JNull then
                JObject Dict.empty

            else
                new

        [ segment ] ->
            if new == JNull then
                case value of
                    JObject fields ->
                        JObject (Dict.remove segment fields)

                    _ ->
                        setIn segment new value

            else
                setIn segment new value

        segment :: rest ->
            let
                inner =
                    getAt [ segment ] value |> Maybe.withDefault (JObject Dict.empty)
            in
            setIn segment (setAt rest new inner) value


setIn : String -> Value -> Value -> Value
setIn segment new value =
    case ( value, String.toInt segment ) of
        ( JArray elements, Just i ) ->
            if i == Array.length elements then
                JArray (Array.push new elements)

            else
                JArray (Array.set i new elements)

        ( JObject fields, _ ) ->
            JObject (Dict.insert segment new fields)

        _ ->
            JObject (Dict.singleton segment new)



-- READING A SURFACE


{-| Where a component is being read: the data model's root, or the item a template is expanding.
-}
type Scope
    = Scope (List String)


root : Scope
root =
    Scope []


resolve : Scope -> String -> List String
resolve (Scope base) path =
    if String.startsWith "/" path then
        pointer path

    else
        base ++ pointer path


{-| A property's value: the literal, or what its `@path` points at. A path that points at nothing is `Nothing`, as a property that is not there is.
-}
read : Surface -> Scope -> Component -> String -> Maybe Value
read s scope c name =
    Dict.get name c.properties
        |> Maybe.andThen
            (\value ->
                case value of
                    JObject fields ->
                        case Dict.toList fields of
                            [ ( "@path", JString path ) ] ->
                                getAt (resolve scope path) s.dataModel

                            _ ->
                                Just value

                    _ ->
                        Just value
            )


type Children
    = Static (List String)
    | Template { path : String, componentId : String }


children : Component -> String -> Maybe Children
children c name =
    case Dict.get name c.properties of
        Just (JArray ids) ->
            ids
                |> Array.foldr
                    (\id acc ->
                        case id of
                            JString string ->
                                Maybe.map ((::) string) acc

                            _ ->
                                Nothing
                    )
                    (Just [])
                |> Maybe.map Static

        Just (JObject fields) ->
            case ( Dict.get "path" fields, Dict.get "componentId" fields ) of
                ( Just (JString path), Just (JString componentId) ) ->
                    Just (Template { path = path, componentId = componentId })

                _ ->
                    Nothing

        _ ->
            Nothing


{-| A template's items: one scope per element of the array at `path`, in order. A path that is no array has none.
-}
items : Surface -> Scope -> String -> List Scope
items s scope path =
    let
        at =
            resolve scope path
    in
    case getAt at s.dataModel of
        Just (JArray elements) ->
            List.map (\i -> Scope (at ++ [ String.fromInt i ])) (List.range 0 (Array.length elements - 1))

        _ ->
            []
