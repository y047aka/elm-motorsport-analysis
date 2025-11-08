# WEC Live Timing - Mock Application

WEC公式ライブタイミングの完全なコピー（モックデータ版）

## 概要

このアプリケーションは、FIA世界耐久選手権（WEC）の公式ライブタイミングアプリケーション（https://fiawec.tv/page/6655a4a4e43bb36e84c8d3cd）の技術スタックを忠実に再現したものです。

### 技術スタック

公式WECアプリケーションと同じ技術を使用：

- **フロントエンド**: Next.js 16 (App Router) + React 19 + TypeScript
- **データ層**: Apollo Client + GraphQL + WebSocket Subscriptions
- **スタイリング**: Tailwind CSS 4 + カスタムCSS
- **リアルタイム**: GraphQL Subscriptions over WebSocket
- **サーバー**: GraphQL Yoga (モックデータ配信)

## 機能

### 実装済み

- ✅ リアルタイムタイミングテーブル
- ✅ ライブポジション更新（1秒ごと）
- ✅ ラップタイム、セクタータイム表示
- ✅ ピットストップ情報
- ✅ ギャップ・インターバル計算
- ✅ ダークモードUI
- ✅ レスポンシブレイアウト
- ✅ 国旗表示（FlagsAPI使用）
- ✅ クラス別カラーリング（HYPERCAR/LMP2/LMGT3）
- ✅ WebSocketによるリアルタイム配信

## セットアップ

### 必要要件

- Node.js 18+
- npm または yarn

### インストール

```bash
cd /workspace/live
npm install
```

### 起動方法

#### 方法1: 個別起動（推奨）

ターミナル1でモックサーバーを起動：
```bash
npm run server
```

ターミナル2でNext.jsアプリを起動：
```bash
npm run dev
```

#### 方法2: 同時起動

```bash
npm run dev:all
```

### アクセス

- **フロントエンド**: http://localhost:3000
- **GraphQL Playground**: http://localhost:4000/graphql

## プロジェクト構造

```
/workspace/live/
├── app/                      # Next.js App Router
│   ├── layout.tsx           # ルートレイアウト（Apollo Provider含む）
│   ├── page.tsx             # メインページ
│   └── globals.css          # グローバルスタイル
├── components/
│   └── TimingTable.tsx      # リアルタイムタイミングテーブル
├── lib/
│   ├── apollo-client.ts     # Apollo Client設定
│   ├── apollo-provider.tsx  # クライアントサイドProvider
│   ├── graphql/
│   │   └── schema.ts        # GraphQLスキーマ定義
│   └── mock-server/
│       ├── mock-data.ts     # モックレースデータ
│       └── resolvers.ts     # GraphQLリゾルバー
├── server.mjs               # スタンドアロンモックサーバー
├── .env.local               # 環境変数
└── package.json
```

## GraphQL API

### エンドポイント

- HTTP: `http://localhost:4000/graphql`
- WebSocket: `ws://localhost:4000/graphql`

### サブスクリプション例

```graphql
subscription TimingUpdated($raceId: ID!) {
  timingUpdated(raceId: $raceId) {
    raceId
    laps
    timeElapsed
    timeRemaining
    flagStatus
    positions {
      position
      number
      team
      currentDriver {
        firstName
        lastName
        countryCode
      }
      lastLapTime
      bestLapTime
      gapToLeader
      inPit
    }
  }
}
```

変数：
```json
{
  "raceId": "qatar-2025"
}
```

## WEC公式との比較

### 実装された機能

| 機能 | WEC公式 | このアプリ | 状態 |
|------|---------|-----------|------|
| Next.js App Router | ✅ | ✅ | 完全一致 |
| GraphQL/WebSocket | ✅ | ✅ | 完全一致 |
| Apollo Client | ✅ | ✅ | 完全一致 |
| リアルタイム更新 | ✅ | ✅ | 完全一致 |
| ダークモード | ✅ | ✅ | 完全一致 |
| レスポンシブUI | ✅ | ✅ | 完全一致 |
| SSR対応 | ✅ | ✅ | 完全一致 |

### データソース

- **WEC公式**: Al Kamel Systems（実データ、法的保護あり）
- **このアプリ**: モックデータ（デモ用、自由に使用可能）

## カスタマイズ

### モックデータの変更

[lib/mock-server/mock-data.ts](lib/mock-server/mock-data.ts) を編集して、チーム、ドライバー、サーキット情報をカスタマイズできます。

### リアルタイム更新頻度

[server.mjs](server.mjs) の `setTimeout(resolve, 1000)` を変更して更新頻度を調整できます（現在は1秒ごと）。

## 今後の拡張可能性

- [ ] 選手権・レースセレクター
- [ ] 多言語対応（i18n: EN/FR/JA）
- [ ] ライブビデオ統合
- [ ] ラップチャート・テレメトリ
- [ ] 履歴データ分析
- [ ] モバイルアプリ（React Native）
- [ ] 実データAPI連携（要ライセンス）

## ライセンスとデータについて

このプロジェクトはデモンストレーション目的のみです。

- Al Kamel Systemsのタイミングデータは法的に保護されています
- モックデータは架空のものであり、実際のレース結果とは無関係です
- 本番環境で実データを使用するには、Sportall/Al Kamel Systemsとの正式な契約が必要です

## 開発者

このアプリケーションは、WEC公式ライブタイミングの技術スタック分析に基づいて構築されました。

---

**🏁 Enjoy the race!**
