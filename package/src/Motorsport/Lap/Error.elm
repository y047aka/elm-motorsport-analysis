module Motorsport.Lap.Error exposing
    ( LapDecodeError(..)
    , decodeLapWithErrorHandling
    , mapDecodeError
    , validateLap
    )

{-| Lapデコードエラー処理とバリデーション機能

設計書の「デコードエラー処理戦略」と「データ検証」に基づく実装。
明確なエラーメッセージと安全なバリデーション機能を提供。

@docs LapDecodeError, decodeLapWithErrorHandling, mapDecodeError, validateLap

-}

import Json.Decode as Decode
import Motorsport.Lap.Decoder as LapDecoder
import Motorsport.Lap.Types exposing (Lap)


{-| Lapデコードエラーの詳細分類
-}
type LapDecodeError
    = UnknownFormat String
    | MissingRequiredField String
    | InvalidFieldValue String String
    | LegacyFormatConversionError String


{-| エラーハンドリング付きでLapをデコード

詳細なエラー情報を提供し、デバッグを支援する。
設計書の「decodeLapWithErrorHandling」に基づく実装。
-}
decodeLapWithErrorHandling : String -> Result LapDecodeError Lap
decodeLapWithErrorHandling jsonString =
    case Decode.decodeString LapDecoder.lapDecoder jsonString of
        Ok lap ->
            case validateLap lap of
                Ok validLap ->
                    Ok validLap

                Err validationError ->
                    Err (InvalidFieldValue "validation" validationError)

        Err decodeError ->
            Err (mapDecodeError decodeError)


{-| Decode.ErrorをLapDecodeErrorにマッピング

具体的なエラー原因を特定し、適切なエラー型に変換する。
-}
mapDecodeError : Decode.Error -> LapDecodeError
mapDecodeError error =
    let
        errorMessage =
            Decode.errorToString error
    in
    case error of
        Decode.Failure message _ ->
            if String.contains "metaData" message then
                MissingRequiredField "metaData"

            else if String.contains "carNumber" message then
                MissingRequiredField "carNumber"

            else if String.contains "driver" message then
                MissingRequiredField "driver"

            else if String.contains "timing" message then
                MissingRequiredField "timing"

            else if String.contains "sectors" message then
                MissingRequiredField "sectors"

            else if String.contains "lap" message then
                MissingRequiredField "lap"

            else
                UnknownFormat message

        _ ->
            UnknownFormat errorMessage


{-| Lapデータの安全性バリデーション

設計書の「データ検証」セクションの検証ルールを実装：
- lap番号の正値チェック
- carNumberの非空チェック
- timing値の非負チェック
-}
validateLap : Lap -> Result String Lap
validateLap lap =
    if lap.lap <= 0 then
        Err "Lap number must be positive"

    else if String.isEmpty lap.metaData.carNumber then
        Err "Car number cannot be empty"

    else if String.isEmpty lap.metaData.driver then
        Err "Driver name cannot be empty"

    else if lap.timing.time < 0 then
        Err "Lap time cannot be negative"

    else if lap.timing.best < 0 then
        Err "Best time cannot be negative"

    else if lap.timing.elapsed < 0 then
        Err "Elapsed time cannot be negative"

    else if lap.sectors.sector_1 < 0 then
        Err "Sector 1 time cannot be negative"

    else if lap.sectors.sector_2 < 0 then
        Err "Sector 2 time cannot be negative"

    else if lap.sectors.sector_3 < 0 then
        Err "Sector 3 time cannot be negative"

    else if lap.sectors.s1_best < 0 then
        Err "Sector 1 best time cannot be negative"

    else if lap.sectors.s2_best < 0 then
        Err "Sector 2 best time cannot be negative"

    else if lap.sectors.s3_best < 0 then
        Err "Sector 3 best time cannot be negative"

    else
        Ok lap