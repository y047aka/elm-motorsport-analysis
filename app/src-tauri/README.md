# Tauri v2 ネイティブアプリ PoC

[ADR 0001](../../docs/adr/0001-native-app-framework-selection.md) の決定（Tauri v2 採用）に基づく最小構成の PoC。

**目的**: elm-pages のビルド出力を Tauri v2 で起動し、静的 JSON（レースデータ）取得まで動作することを確認する。

## この PoC が示すこと

既存フロントエンドは **無改修** で Tauri に載る想定。根拠は以下:

- フロントは elm-pages の静的プリレンダリング出力で完結しており、サーバサイドロジックを持たない。
- レースデータ・画像は `/static/wec/**/*.json`・`/static/images/...` の **絶対パス**（`app/src/Data/Series/Wec_2025.elm` 等）で参照され、`Shared.elm` の `Http.get` でランタイム取得される。
- elm-pages のビルドで `static/` は `dist/` ルートへ出力される。Tauri は `frontendDist`（`../dist`）を `tauri://localhost/` で配信するため、`/static/...` は `tauri://localhost/static/...` として **同一オリジン**で解決される。
- したがって CSP 緩和や `http`/`fs` 権限の追加は不要（`capabilities/default.json` は `core:default` のみ）。

## 構成

```
app/
├── dist/                     # elm-pages のビルド出力（frontendDist が指す先）
├── static/wec/**/*.json      # レースデータ（dist/static/ へ出力される）
└── src-tauri/
    ├── Cargo.toml            # cli/ の workspace とは独立した単独クレート
    ├── tauri.conf.json       # frontendDist=../dist, devUrl=:1234
    ├── build.rs
    ├── capabilities/default.json
    ├── icons/                # プレースホルダ（実運用前に差し替え）
    └── src/{main,lib}.rs     # 追加コマンドなしの最小エントリ
```

## 前提ツール

Tauri ツールチェーン（`cargo-tauri`）は **flake に統合済み**。`nix develop` / `nix run` を使えば
個別インストールは不要。
- macOS/Windows … OS 標準 WebView を利用するため追加のシステム依存は不要。
- Linux … WebView 一式（`webkitgtk_4_1`, `libsoup_3`, `gtk3`）が必要。flake が自動で用意する。

nix を使わず素の環境で動かす場合のみ、`cargo install tauri-cli --version '^2' --locked`
（または `cd app && pnpm add -D @tauri-apps/cli@^2`）で CLI を導入する。

## 起動手順（開発）

**推奨（flake 経由）** — リポジトリルートで:

```bash
# 依存を用意（初回のみ）
nix develop --command pnpm install --frozen-lockfile

# アイコンをプレースホルダから生成（初回のみ / .icns・.ico を含め全サイズ生成）
nix develop --command bash -c 'cd app/src-tauri && cargo tauri icon icons/icon.png'

# 開発起動（beforeDevCommand で `pnpm run start` が走り、:1234 の elm-pages dev を読み込む）
nix run .#tauri-dev
```

> **cwd に注意**: `cargo tauri` は `app/` を cwd にして実行すること
> （`nix run .#tauri-dev` は内部で `cd app` 済み）。beforeDevCommand の `pnpm run start` は
> `app/package.json` を基準に動くため、`app/src-tauri/` を cwd にすると失敗する。
> 手動起動する場合は `cd app && cargo tauri dev`。

## 動作確認チェックリスト

- [ ] ウィンドウが起動し、トップ（Index）が表示される
- [ ] `/wec/2025/le_mans_24h` 等のルートへ遷移できる
- [ ] レースデータ（`/static/wec/2025/*.json` と `*_laps.json`）が `Http.get` で取得され、Leaderboard / Tracker が描画される
- [ ] マニュファクチャラーロゴ（`/static/images/...`）が表示される

## 本番ビルド

```bash
# beforeBuildCommand で `pnpm run build` → dist を同梱してネイティブバイナリを生成
nix run .#tauri-build
```

## この環境での検証状況（正直な記録）

本 PoC を作成した remote 実行環境には **webkit2gtk / Tauri CLI / elm・nix ツールチェーンが無い**ため、
`nix run .#tauri-dev` による GUI 起動と `nix run .#tauri-build` の実行検証は **未実施**。
flake / 構成一式は Tauri v2 の標準スキーマに沿って用意済みで、上記前提ツールの揃った環境（メンテナのローカル / nix）で
起動確認を行うこと。

## 残課題（実装フェーズ）

1. **アイコン**: プレースホルダを実アイコンへ差し替え。
2. ~~**Nix flake**: `nix develop` に Tauri ツールチェーンを追加。~~ → **対応済み**
   （`mkTauriApp` / `nix run .#tauri-dev` / `.#tauri-build` / devShell に `cargo-tauri` 追加）。
3. **CI 差し替え**: → **一部対応**。macOS 向けビルドワークフロー
   `.github/workflows/tauri-build.yml`（手動実行 / `nix run .#tauri-build` で .app・.dmg 生成）を追加。
   旧 Web 公開ワークフロー `.github/workflows/gh-pages.yml` の削除が残（下記「未了」参照）。
   Windows / Linux 対応、タグ連動の自動リリースは今後の課題。
4. **Rust CLI 統合方針**: `motorsport` クレート（`../../cli/motorsport`）をライブラリ結合するか、
   CLI をサイドカー同梱するかを決定（アプリ内データ更新の要否次第）。
5. **配布・署名・自動更新**: コード署名（macOS notarization / Windows signing）と Tauri Updater の要否判断。

### 未了（要手動対応）

- **`gh-pages.yml` の削除**: Web 公開を完全に終了するには旧ワークフローを削除する必要があるが、
  remote 実行環境ではワークフローファイルの削除操作が権限で拒否されたため未実施。
  メンテナのローカルで `git rm .github/workflows/gh-pages.yml` を実行すること。
