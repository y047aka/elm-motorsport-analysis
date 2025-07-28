module Motorsport.Lap.Debug exposing
    ( DebugInfo
    , formatDecodeError
    , lapToDebugString
    , debugDecodeAttempt
    , compareFormats
    , validateJsonStructure
    )

{-| Lapデバッグ・ログ機能

設計書の「デバッグ・ログ機能」に基づいて、
開発時のデバッグとトラブルシューティングを支援する機能を提供。

@docs DebugInfo, formatDecodeError, lapToDebugString, debugDecodeAttempt
@docs compareFormats, validateJsonStructure

-}

import Json.Decode as Decode
import Json.Encode as Encode
import Motorsport.Lap.Decoder as LapDecoder
import Motorsport.Lap.Error as LapError exposing (LapDecodeError(..))
import Motorsport.Lap.Types exposing (Lap, LapMetaData, TimingData, SectorData)


{-| デバッグ情報の構造体
-}
type alias DebugInfo =
    { attemptedFormat : String
    , success : Bool
    , errorMessage : Maybe String
    , processingTime : Maybe Float
    , dataSize : Int
    }


{-| デコードエラーを人間読みやすい形式にフォーマット

設計書の「エラーメッセージの改善」に対応
-}
formatDecodeError : LapDecodeError -> String
formatDecodeError error =
    case error of
        UnknownFormat message ->
            "未知のフォーマット: " ++ message ++ "\n"
                ++ "新形式は 'metaData' オブジェクトを含む必要があります。\n"
                ++ "レガシー形式は 'carNumber', 'driver', 'lap' フィールドが必須です。"

        MissingRequiredField fieldName ->
            "必須フィールドが見つかりません: " ++ fieldName ++ "\n"
                ++ getFieldRequirements fieldName

        InvalidFieldValue fieldName value ->
            "無効なフィールド値: " ++ fieldName ++ " = " ++ value ++ "\n"
                ++ getFieldValidationRules fieldName

        LegacyFormatConversionError message ->
            "レガシー形式の変換エラー: " ++ message ++ "\n"
                ++ "レガシー形式から新形式への変換中に問題が発生しました。"


{-| フィールド要件の説明を取得
-}
getFieldRequirements : String -> String
getFieldRequirements fieldName =
    case fieldName of
        "metaData" ->
            "新形式では metaData オブジェクトが必要です: {\"carNumber\": \"...\", \"driver\": \"...\"}"

        "carNumber" ->
            "車両番号は必須です（文字列）"

        "driver" ->
            "ドライバー名は必須です（文字列）"

        "lap" ->
            "ラップ番号は必須です（正の整数）"

        "timing" ->
            "新形式では timing オブジェクトが必要です: {\"time\": 0, \"best\": 0, \"elapsed\": 0}"

        "sectors" ->
            "新形式では sectors オブジェクトが必要です: sector_1, sector_2, sector_3, s1_best, s2_best, s3_best"

        _ ->
            "詳細は設計書を参照してください"


{-| フィールドバリデーションルールの説明を取得
-}
getFieldValidationRules : String -> String
getFieldValidationRules fieldName =
    case fieldName of
        "lap" ->
            "ラップ番号は正の整数である必要があります"

        "carNumber" ->
            "車両番号は空でない文字列である必要があります"

        "driver" ->
            "ドライバー名は空でない文字列である必要があります"

        "timing" ->
            "タイミング値は非負の数値である必要があります"

        _ ->
            "値の形式を確認してください"


{-| Lapオブジェクトをデバッグ用文字列に変換

構造化されたLapデータを人間読みやすい形式で出力
-}
lapToDebugString : Lap -> String
lapToDebugString lap =
    let
        metaDataStr =
            "MetaData:\n"
                ++ "  車両番号: " ++ lap.metaData.carNumber ++ "\n"
                ++ "  ドライバー: " ++ lap.metaData.driver ++ "\n"

        basicStr =
            "基本情報:\n"
                ++ "  ラップ: " ++ String.fromInt lap.lap ++ "\n"
                ++ "  ポジション: " ++ (Maybe.map String.fromInt lap.position |> Maybe.withDefault "N/A") ++ "\n"

        timingStr =
            "タイミング:\n"
                ++ "  ラップタイム: " ++ String.fromInt lap.timing.time ++ "ms\n"
                ++ "  ベストタイム: " ++ String.fromInt lap.timing.best ++ "ms\n"
                ++ "  経過時間: " ++ String.fromInt lap.timing.elapsed ++ "ms\n"

        sectorStr =
            "セクター:\n"
                ++ "  S1: " ++ String.fromInt lap.sectors.sector_1 ++ "ms (ベスト: " ++ String.fromInt lap.sectors.s1_best ++ "ms)\n"
                ++ "  S2: " ++ String.fromInt lap.sectors.sector_2 ++ "ms (ベスト: " ++ String.fromInt lap.sectors.s2_best ++ "ms)\n"
                ++ "  S3: " ++ String.fromInt lap.sectors.sector_3 ++ "ms (ベスト: " ++ String.fromInt lap.sectors.s3_best ++ "ms)\n"

        miniSectorStr =
            "ミニセクター: " ++ (Maybe.map (\_ -> "あり") lap.miniSectors |> Maybe.withDefault "なし") ++ "\n"
    in
    metaDataStr ++ basicStr ++ timingStr ++ sectorStr ++ miniSectorStr


{-| デコード試行のデバッグ情報を生成

設計書の「デコード過程の詳細ログ」に対応
-}
debugDecodeAttempt : String -> DebugInfo
debugDecodeAttempt jsonString =
    let
        dataSize =
            String.length jsonString

        ( attemptedFormat, success, errorMessage ) =
            case Decode.decodeString LapDecoder.lapDecoder jsonString of
                Ok _ ->
                    -- どちらの形式で成功したかを判定
                    case Decode.decodeString (Decode.field "metaData" Decode.value) jsonString of
                        Ok _ ->
                            ( "新形式", True, Nothing )

                        Err _ ->
                            ( "レガシー形式", True, Nothing )

                Err error ->
                    ( "不明", False, Just (Decode.errorToString error) )
    in
    { attemptedFormat = attemptedFormat
    , success = success
    , errorMessage = errorMessage
    , processingTime = Nothing -- 実際の測定は実装環境に依存
    , dataSize = dataSize
    }


{-| 両フォーマットでの処理結果を比較

設計書の「形式間比較機能」に対応
-}
compareFormats : String -> String -> { legacy : DebugInfo, newFormat : DebugInfo, recommendation : String }
compareFormats legacyJsonString newFormatJsonString =
    let
        legacyDebug =
            debugDecodeAttempt legacyJsonString

        newFormatDebug =
            debugDecodeAttempt newFormatJsonString

        recommendation =
            if legacyDebug.success && newFormatDebug.success then
                "両方の形式が正常に処理されました。新形式の使用を推奨します。"

            else if legacyDebug.success && not newFormatDebug.success then
                "レガシー形式のみ成功。新形式への移行を検討してください。"

            else if not legacyDebug.success && newFormatDebug.success then
                "新形式のみ成功。適切な形式です。"

            else
                "両方の形式で失敗。JSONの構造を確認してください。"
    in
    { legacy = legacyDebug
    , newFormat = newFormatDebug
    , recommendation = recommendation
    }


{-| JSON構造の妥当性を検証

設計書の「JSON構造検証」に対応
-}
validateJsonStructure : String -> List String
validateJsonStructure jsonString =
    let
        basicValidation =
            case Decode.decodeString Decode.value jsonString of
                Ok _ ->
                    []

                Err _ ->
                    [ "無効なJSON形式です" ]

        structureValidation =
            if basicValidation == [] then
                checkStructuralRequirements jsonString

            else
                []
    in
    basicValidation ++ structureValidation


{-| 構造的要件をチェック
-}
checkStructuralRequirements : String -> List String
checkStructuralRequirements jsonString =
    let
        hasField fieldName =
            case Decode.decodeString (Decode.field fieldName Decode.value) jsonString of
                Ok _ ->
                    True

                Err _ ->
                    False

        hasMetaData =
            hasField "metaData"

        hasLegacyFields =
            hasField "carNumber" && hasField "driver" && hasField "lap"

        issues =
            []
    in
    if not hasMetaData && not hasLegacyFields then
        [ "新形式にも レガシー形式にも対応していません"
        , "新形式: 'metaData' オブジェクトが必要"
        , "レガシー形式: 'carNumber', 'driver', 'lap' フィールドが必要"
        ]

    else if hasMetaData then
        checkNewFormatRequirements jsonString

    else
        checkLegacyFormatRequirements jsonString


{-| 新形式の要件をチェック
-}
checkNewFormatRequirements : String -> List String
checkNewFormatRequirements jsonString =
    let
        requiredFields =
            [ "metaData", "lap", "timing", "sectors", "performance" ]

        missingFields =
            requiredFields
                |> List.filter
                    (\field ->
                        case Decode.decodeString (Decode.field field Decode.value) jsonString of
                            Ok _ ->
                                False

                            Err _ ->
                                True
                    )
    in
    if missingFields == [] then
        []

    else
        [ "新形式で不足しているフィールド: " ++ String.join ", " missingFields ]


{-| レガシー形式の要件をチェック
-}
checkLegacyFormatRequirements : String -> List String
checkLegacyFormatRequirements jsonString =
    let
        requiredFields =
            [ "carNumber", "driver", "lap", "time", "best", "sector_1", "sector_2", "sector_3", "elapsed" ]

        missingFields =
            requiredFields
                |> List.filter
                    (\field ->
                        case Decode.decodeString (Decode.field field Decode.value) jsonString of
                            Ok _ ->
                                False

                            Err _ ->
                                True
                    )
    in
    if missingFields == [] then
        []

    else
        [ "レガシー形式で不足しているフィールド: " ++ String.join ", " missingFields ]