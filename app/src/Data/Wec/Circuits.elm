module Data.Wec.Circuits exposing (Drawing, drawingFor)

{-| The WEC circuits the app draws to their own shape, and the two files each
drawing is read from.

@docs Drawing, drawingFor

-}

import Http
import Json.Decode as Decode exposing (Decoder)
import Motorsport.Circuit.Direction exposing (Direction)
import Motorsport.Circuit.Layout exposing (Layout)
import Motorsport.Wec.Circuit.Barcelona.Layout as BarcelonaLayout
import Motorsport.Wec.Circuit.Cota.Layout as CotaLayout
import Motorsport.Wec.Circuit.Fuji.Layout as FujiLayout
import Motorsport.Wec.Circuit.Geometry exposing (Geometry)
import Motorsport.Wec.Circuit.Imola.Layout as ImolaLayout
import Motorsport.Wec.Circuit.LeMans.Layout as LeMansLayout
import Motorsport.Wec.Circuit.Map as Map
import Motorsport.Wec.Circuit.Monza.Layout as MonzaLayout
import Motorsport.Wec.Circuit.SaoPaulo.Layout as SaoPauloLayout
import Motorsport.Wec.Circuit.Spa.Layout as SpaLayout
import Task exposing (Task)


type alias Drawing =
    { layout : Layout
    , direction : Direction
    }


{-| Which circuits are drawn to their own shape, by the word the summary sends.
`geometry-contract.spec.ts` keeps these words in step with the words Flix's `Circuit.jsonValue` can send, and with the files behind them.
-}
drawingFor : String -> Maybe (Task Http.Error Drawing)
drawingFor circuit =
    case circuit of
        "barcelona" ->
            Just (fetchDrawing circuit Map.intermediatesDecoder BarcelonaLayout.decoder BarcelonaLayout.layout)

        "cota" ->
            Just (fetchDrawing circuit Map.intermediatesDecoder CotaLayout.decoder CotaLayout.layout)

        "le_mans" ->
            Just (fetchDrawing circuit LeMansLayout.mapDecoder LeMansLayout.decoder LeMansLayout.layout)

        "monza" ->
            Just (fetchDrawing circuit Map.intermediatesDecoder MonzaLayout.decoder MonzaLayout.layout)

        "fuji" ->
            Just (fetchDrawing circuit Map.intermediatesDecoder FujiLayout.decoder FujiLayout.layout)

        "spa" ->
            Just (fetchDrawing circuit Map.intermediatesDecoder SpaLayout.decoder SpaLayout.layout)

        "sao_paulo" ->
            Just (fetchDrawing circuit Map.intermediatesDecoder SaoPauloLayout.decoder SaoPauloLayout.layout)

        "imola" ->
            Just (fetchDrawing circuit Map.intermediatesDecoder ImolaLayout.decoder ImolaLayout.layout)

        _ ->
            Nothing


{-| A circuit's map, then its geometry: the geometry is checked against the lap the map gives, so it waits for the map.
-}
fetchDrawing : String -> Decoder map -> (map -> Decoder Geometry) -> (map -> Geometry -> Layout) -> Task Http.Error Drawing
fetchDrawing circuit mapDecoder geometryDecoder layoutOf =
    getJson ("/static/circuit-maps/" ++ circuit ++ ".json") mapDecoder
        |> Task.andThen
            (\map ->
                getJson ("/static/geometry/" ++ circuit ++ ".geojson") (geometryDecoder map)
                    |> Task.map (\geometry -> { layout = layoutOf map geometry, direction = geometry.direction })
            )


getJson : String -> Decoder a -> Task Http.Error a
getJson url decoder =
    Http.task
        { method = "GET"
        , headers = []
        , url = url
        , body = Http.emptyBody
        , resolver = Http.stringResolver (resolveJson decoder)
        , timeout = Nothing
        }


resolveJson : Decoder a -> Http.Response String -> Result Http.Error a
resolveJson decoder response =
    case response of
        Http.BadUrl_ url ->
            Err (Http.BadUrl url)

        Http.Timeout_ ->
            Err Http.Timeout

        Http.NetworkError_ ->
            Err Http.NetworkError

        Http.BadStatus_ metadata _ ->
            Err (Http.BadStatus metadata.statusCode)

        Http.GoodStatus_ _ body ->
            Decode.decodeString decoder body
                |> Result.mapError (Decode.errorToString >> Http.BadBody)
