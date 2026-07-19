# ADR 0001: ネイティブアプリ化に向けた技術選定

- ステータス: 提案（Proposed）
- 日付: 2026-07-19
- 決定者: プロジェクトメンテナ

## 背景 / コンテキスト

本アプリケーション（elm-motorsport-analysis）は、現在 **elm-pages 3.x** で静的サイトとしてビルドし、**GitHub Pages** で Web 公開している。方針として **Web 公開を終了し、Tauri を用いたネイティブアプリへ移行** したい。

まず「本当に Tauri が適切か」を、競合フレームワークと比較したうえで判断する。

### 現状構成の整理（移行難易度に直結する重要事項）

| 項目 | 現状 |
| --- | --- |
| フロントエンド | Elm 0.19.1 + elm-pages 3.x（静的プリレンダリング） |
| スタイリング | Tailwind CSS 4.x / elm-css / daisyUI |
| データ取得 | `app/static/**/*.json` を **ランタイムに `Http.get` で取得**（`app/app/Shared.elm`） |
| バックエンド | 実質なし（`functions/server-render` は存在するが、デプロイは純粋な静的 GitHub Pages） |
| データ処理 | **Rust CLI**（`/cli`）が CSV → JSON へ変換（ビルド時ツール） |
| デプロイ | `.github/workflows/gh-pages.yml` で `nix run .#build` → GitHub Pages |

**結論として、フロントエンドは「静的アセット + クライアント側 JSON フェッチ」で完結しており、バックエンドロジックを持たない。** これは WebView ラッパー型のネイティブ化と非常に相性が良い。加えて **データ処理層が既に Rust** であることは、後述する技術選定に直接影響する。

## 検討した選択肢

WebView ラッパー型を中心に、主要な代替も含めて比較した。

### 1. Tauri v2（Rust バックエンド + OS ネイティブ WebView）

- **バンドルサイズ**: 約 3〜10 MB（OS の WebView を利用し Chromium を同梱しない）
- **メモリ**: Electron 比で約 50% 削減、起動も約 3〜4 倍高速
- **バックエンド言語**: Rust
- **セキュリティ**: 権限（capability）ベースの細かいアクセス制御、デフォルトで堅牢
- **本プロジェクトとの親和性**:
  - **既存の Rust CLI（CSV→JSON 変換）を Tauri の Rust バックエンドへ統合可能**。CLI を別プロセスで叩く／ライブラリとして取り込む双方が現実的で、コード資産を活かせる。
  - フロントは静的アセットなので、`frontendDist` に elm-pages のビルド出力を渡すだけで載る見込み。
- **懸念**: OS 依存 WebView のためレンダリング差異（特に旧 WebView2 / WebKitGTK）が出る場合がある。Elm/CSS は比較的枯れており影響は限定的と想定。

### 2. Electron（Node.js + Chromium 同梱）

- **バンドルサイズ**: 約 85〜150 MB（Chromium 同梱）
- **メモリ**: 最も重い
- **利点**: レンダリングが全 OS で完全一致、コード署名・自動更新のエコシステムが最も成熟
- **本プロジェクトとの親和性**: バックエンドが Node 前提。**既存の Rust 資産を活かせず**、重量級。本アプリはレンダリング一貫性がクリティカルな要件でもない。→ オーバースペック。

### 3. Wails v2/v3（Go バックエンド + OS ネイティブ WebView）

- **バンドルサイズ**: 約 5〜15 MB（Tauri と同等クラス）
- **バックエンド言語**: Go
- **本プロジェクトとの親和性**: 軽量で優秀だが、**バックエンドが Go**。本プロジェクトは既に Rust 資産を持つため、言語をもう一つ増やすことになりメンテコストが上がる。→ Tauri に対する明確な優位性なし。

### 4. Neutralinojs（軽量 / 言語非依存）

- 超軽量だがエコシステム・ネイティブ API が限定的。細かい OS 連携や将来的な機能拡張で制約が出やすい。→ 本格的なデスクトップアプリには力不足。

### 5. Flutter Desktop / .NET MAUI / ネイティブ実装

- UI を **全面書き直し** が必要。既存の Elm/elm-css 資産を捨てることになり、移行コストが過大。→ 却下。

### 6. PWA（インストール可能な Web アプリ）に留める

- 「Web 公開を終了しネイティブ化する」という方針に反する（配布は依然 Web サーバ経由）。→ 方針不一致。

## 比較サマリ

| 観点 | **Tauri v2** | Electron | Wails | Neutralino |
| --- | --- | --- | --- | --- |
| バンドルサイズ | ◎ 3〜10MB | △ 85〜150MB | ◎ 5〜15MB | ◎ 極小 |
| メモリ / 起動速度 | ◎ | △ | ◎ | ◎ |
| 既存 Rust 資産の活用 | ◎ | ✕ | ✕ (Go) | ✕ |
| 既存 Elm フロント流用 | ◎ | ◎ | ◎ | ◎ |
| エコシステム成熟度 | ○ | ◎ | ○ | △ |
| セキュリティモデル | ◎ | ○ | ○ | △ |
| レンダリング一貫性 | ○ | ◎ | ○ | ○ |

## 決定

**Tauri v2 を採用する。**

決め手は以下の 3 点:

1. **既存資産との親和性が最も高い** — フロントは静的アセットとしてそのまま載せられ、**データ処理層が既に Rust なので Tauri の Rust バックエンドへ自然に統合できる**。言語を増やさない。
2. **軽量・高速** — OS ネイティブ WebView によりバンドル数 MB・低メモリ・高速起動。ローカルのレース分析ツールとして配布・起動体験が良い。
3. **セキュリティ / 保守性** — 権限ベースのモデルと活発なコミュニティ。Web 版を畳んでネイティブに一本化する長期方針に合致。

Electron はレンダリング完全一致やコード署名・自動更新の成熟が必須の場合の代替として妥当だが、本アプリの要件ではオーバースペックであり、既存 Rust 資産も活かせないため採用しない。

## 想定される移行上の技術課題（次フェーズで詳細検討）

Tauri 採用を前提に、実装フェーズで解消すべき論点を先出ししておく:

1. **elm-pages のルーティングと静的出力の載せ方**
   - 現状は事前レンダリング済みルート + クライアント側 `Http.get`。Tauri の `frontendDist` / カスタムプロトコル（`tauri://localhost`）配下でルート解決とアセットパスが正しく動くか検証が必要。
   - 単一エントリの SPA として畳む選択肢、または elm-pages のまま静的出力を載せる選択肢の比較。
2. **静的 JSON データの同梱方法**
   - `app/static/**/*.json` を Tauri リソースとして同梱し、`Http.get`（相対パス）で従来どおり読むか、Tauri コマンド経由（Rust）でファイルを返す方式へ寄せるか。
3. **Rust CLI の統合方式**
   - CLI をサイドカー（別バイナリ）として同梱するか、`motorsport` クレートをライブラリとして Tauri バックエンドへ取り込むか。データ更新をアプリ内で行うかは要件次第。
4. **ビルド / CI の再構成**
   - `gh-pages.yml` を廃し、`tauri build` によるマルチプラットフォーム（macOS / Windows / Linux）リリースワークフローへ差し替え。Nix flake への Tauri ツールチェーン追加。
5. **配布・署名・自動更新**
   - コード署名（macOS notarization / Windows signing）と Tauri Updater の要否を決定。

## 次のアクション

- 本 ADR のレビュー・承認。
- 承認後、上記「移行上の技術課題」を検証する PoC（elm-pages ビルド出力を Tauri v2 の最小構成で起動し、静的 JSON 取得まで動作確認）を別ブランチで着手。

## 参考

- [Tauri vs Electron 2026 (PkgPulse Guides)](https://www.pkgpulse.com/guides/electron-vs-tauri-2026)
- [Tauri v2 vs Electron 2026: The Honest Comparison (BuildMVPFast)](https://www.buildmvpfast.com/blog/tauri-v2-vs-electron-desktop-apps-2026)
- [Desktop Apps from Web: Tauri vs Electron vs Deno vs Wails 2026 (DigitalApplied)](https://www.digitalapplied.com/blog/desktop-apps-web-stack-tauri-electron-deno-wails-2026)
- [Tauri vs. Electron: performance, bundle size, and the real trade-offs (gethopp)](https://www.gethopp.app/blog/tauri-vs-electron)
- [Tauri vs Electron vs Neutralinojs 2026 (pikvue)](https://pikvue.com/tauri-vs-electron-vs-neutralinojs-2026-best-desktop-app-framework-compared/)
