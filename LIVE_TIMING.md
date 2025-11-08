# Live Timing 機能実装ドキュメント

このドキュメントは、レースアプリケーションにLive Timing機能を追加する実装の詳細を説明します。

## 実装概要

このアプリケーションは従来、レース後に配信されるCSVファイルに基づいて動作していましたが、Live Timing機能の追加により、レース中のリアルタイムデータも処理できるようになりました。

## アーキテクチャ

### データフロー

```
WebSocket Server (Mock or Real)
         ↓
    index.ts (WebSocket Client)
         ↓
    Elm Ports
         ↓
    Shared.elm (State Management)
         ↓
    RaceControl.elm (Data Processing)
         ↓
    UI Components
```

## 実装済みコンポーネント

### Phase 1: WebSocket基盤構築 ✅

**ファイル**: `app/index.ts`

TypeScript側でWebSocket接続を管理:
- 自動再接続（指数バックオフ）
- エラーハンドリング
- Elmポートとの統合

**主な機能**:
- `connectLiveTiming(url)`: WebSocket接続を確立
- `disconnectLiveTiming()`: 接続を切断
- 最大10回の自動再接続試行

### Phase 2: データモデル拡張 ✅

#### 2.1 LiveTiming.elm ✅

**ファイル**: `package/src/Motorsport/LiveTiming.elm`

Live Timingデータ型とデコーダー:

```elm
type ConnectionStatus
    = Disconnected
    | Connecting
    | Connected
    | Reconnecting Int
    | Error String

type alias LiveUpdateData =
    { timestamp : Time.Posix
    , raceTime : Duration
    , updatedCars : List CarUpdate
    , newEvents : List TimelineEvent
    }
```

#### 2.2 RaceControl.elm拡張 ✅

**ファイル**: `package/src/Motorsport/RaceControl.elm`

増分更新ロジックを追加:

```elm
applyLiveUpdate : LiveUpdateData -> Model -> Model
```

**機能**:
- 既存のタイムラインイベントに新しいイベントを追加
- 車両データの部分更新
- 順位の自動再計算

### Phase 3: Shared.elm更新 ✅

**ファイル**: `app/app/Shared.elm`

グローバル状態管理にLive Timing機能を統合:

**追加フィールド**:
```elm
type alias Model =
    { ...
    , liveTimingConnection : ConnectionStatus
    , liveTimingEnabled : Bool
    }
```

**追加メッセージ**:
```elm
type Msg
    = ...
    | ConnectLiveTiming String
    | DisconnectLiveTiming
    | LiveTimingMessageReceived Decode.Value
    | ToggleLiveTiming
```

**ポート定義**:
```elm
port connectLiveTiming : String -> Cmd msg
port disconnectLiveTiming : () -> Cmd msg
port liveTimingMessage : (Decode.Value -> msg) -> Sub msg
```

### Phase 4: UI実装 🚧

#### 4.1 LiveTimingControl Widget ✅

**ファイル**: `package/src/Motorsport/Widget/LiveTimingControl.elm`

接続状態インジケーターとコントロールUI:
- 接続状態表示（色付きインジケーター）
- Connect/Disconnectボタン
- Live Timingトグルスイッチ

#### 4.2 ページ統合 ⏳

**TODO**: WECレースページにLiveTimingControlウィジェットを追加
- `app/app/Route/Wec/Season_/Event_.elm`にインポート
- ヘッダーまたはサイドバーにウィジェットを配置

### Phase 5: モックWebSocketサーバー ✅

**ファイル**: `tools/mock-live-timing-server.js`

開発・テスト用のモックサーバー:

**機能**:
- 既存のJSONファイルからレースデータを読み込み
- タイムラインイベントを時系列で配信
- 再生速度調整（デフォルト: 10倍速）

**使用方法**:
```bash
# wsパッケージをインストール
npm install

# モックサーバー起動
npm run mock:live-timing

# カスタムファイルで起動
node tools/mock-live-timing-server.js \
  --file app/static/wec/2025/fuji_6h.json \
  --laps-file app/static/wec/2025/fuji_6h_laps.json \
  --speed 20 \
  --port 8080
```

**デフォルト設定**:
- ポート: 8080
- URL: `ws://localhost:8080`
- 再生速度: 20倍速
- データ: Fuji 6h 2025

## データフォーマット

### WebSocketメッセージフォーマット

#### 接続確立時

```json
{
  "type": "connected",
  "timestamp": 1234567890123
}
```

#### Live Update

```json
{
  "type": "data",
  "payload": {
    "timestamp": 1234567890123,
    "raceTime": "01:23:45.678",
    "updatedCars": [
      {
        "carNumber": "50",
        "position": 1,
        "currentLap": { ... },
        "lastCompletedLap": { ... },
        "gap": "0.0",
        "interval": "Leader",
        "inPit": false
      }
    ],
    "newEvents": [
      {
        "event_time": "01:23:45.678",
        "event_type": {
          "CarEvent": [
            "50",
            {
              "LapCompleted": [
                10,
                { "nextLap": { ... } }
              ]
            }
          ]
        }
      }
    ]
  }
}
```

#### エラー

```json
{
  "type": "error",
  "error": "Connection failed",
  "timestamp": 1234567890123
}
```

#### 切断

```json
{
  "type": "disconnected",
  "code": 1000,
  "reason": "Normal closure",
  "timestamp": 1234567890123
}
```

## 使用方法

### 開発環境でのテスト

1. **モックサーバーを起動**:
   ```bash
   npm run mock:live-timing
   ```

2. **アプリケーションを起動**:
   ```bash
   npm start
   ```

3. **ブラウザでページを開く**:
   - http://localhost:1234/wec/2025/fuji_6h

4. **Live Timingを有効化**:
   - "Live Timing"トグルをONにする
   - "Connect"ボタンをクリック
   - 接続状態が"Connected"になることを確認

5. **リアルタイム更新を確認**:
   - レースデータが自動的に更新される
   - タイムラインイベントが追加される

### 本番環境

実際のLive Timing APIに接続する場合:

1. **WebSocket URLを設定**:
   ```elm
   -- Shared.elmまたは設定ファイルで
   liveTimingUrl = "wss://api.example.com/live-timing"
   ```

2. **認証が必要な場合**:
   - WebSocket接続時に認証トークンを送信
   - `index.ts`の`connectWebSocket`関数を修正

## 今後の拡張

### 未実装機能

1. **UIページ統合** ⏳
   - WECレースページへのLiveTimingControlウィジェット追加
   - Formula Eページへの対応

2. **アニメーション** ⏳
   - LiveStandingsウィジェットでの順位変動アニメーション
   - ラップタイム更新時のハイライト効果

3. **エラーハンドリング改善** ⏳
   - より詳細なエラーメッセージ
   - リトライロジックの最適化
   - オフライン検出

4. **パフォーマンス最適化** ⏳
   - 大規模データ（24時間レース）の処理
   - メモリ使用量の最適化
   - レンダリングパフォーマンス改善

5. **追加機能** 💡
   - Live Timing設定画面（URL、再接続設定など）
   - データのローカル保存・再生機能
   - 複数レースの同時表示
   - 通知機能（ピットストップ、インシデントなど）

## トラブルシューティング

### 接続できない

1. **モックサーバーが起動しているか確認**:
   ```bash
   # サーバープロセスを確認
   ps aux | grep mock-live-timing
   ```

2. **ポートが使用可能か確認**:
   ```bash
   lsof -i :8080
   ```

3. **ブラウザコンソールでエラーを確認**:
   - F12で開発者ツールを開く
   - Console タブでエラーメッセージを確認

### データが更新されない

1. **Live Timingが有効になっているか確認**
2. **接続状態が"Connected"になっているか確認**
3. **ブラウザコンソールでWebSocketメッセージを確認**:
   ```javascript
   // コンソールで実行
   console.log('[LiveTiming] messages')
   ```

### パフォーマンスが悪い

1. **再生速度を下げる**:
   ```bash
   npm run mock:live-timing -- --speed 10
   ```

2. **ブラウザのパフォーマンスプロファイラーを使用**:
   - F12 → Performance タブ
   - Record開始 → 操作 → Record停止
   - ボトルネックを特定

## 技術スタック

- **フロントエンド**: Elm 0.19.1
- **WebSocket**: Native WebSocket API (Browser) + ws (Node.js)
- **ビルドツール**: Vite 6.2.4
- **CSS**: TailwindCSS 4.1.12, daisyUI 5
- **モックサーバー**: Node.js

## 貢献

このプロジェクトは私的利用に限定されています。

## ライセンス

Private use only.
