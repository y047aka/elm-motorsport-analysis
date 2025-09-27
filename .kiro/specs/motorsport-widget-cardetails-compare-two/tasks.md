# Tasks

## 概要
CarDetailsの後方互換を保ちつつ、2台比較の新UI/描画を追加する。実装は新モジュール群で行い、ルート側での遷移・操作連携を行う。

## 実装タスク
- [ ] 新規 `Motorsport.Widget.CarDetails.Compare` を追加（`Props`, `Alignment(..)`, `view` 公開）
- [ ] Compare Header（A/Bメタ・画像・凡例・操作領域）
- [ ] KPI Row（Current/Last を2列比較）
- [ ] Histogram2（2系列オーバーレイ）。既存 `Motorsport.Chart.Histogram` を参考に薄いラッパー作成
- [ ] PositionProgression2（対象2台のみを描画）。既存 `PositionProgression` から最小構成を移植
- [ ] LapTimeProgression2（対象2台のみを描画）。既存 `LapTimeProgression` から最小構成を移植
- [ ] アラインメント切替（`ByLap`/`ByElapsedTime`）の分岐ロジック（X軸変換）
- [ ] A/B `Swap` と `ClearB` 操作用の `actions` レコードを `Props` に追加（`swap : msg`, `clearB : msg`, `toggleAlignment : msg`）
- [ ] アクセシビリティ（色以外の区別: 線種/凡例/テキスト）、画像alt付与
- [ ] HalfModal向けレスポンシブ: グリッド→1カラム化、チャートサイズ調整

## ルーティング/統合タスク（app側）
- [ ] Leaderboard行からの「+比較」導線追加（B未選択時はピッカー表示）
- [ ] Compare `actions` をルートの `Msg` に接続（Swap/Clear/Alignment切替とURL同期）

## データ/整合タスク
- [ ] 同一イベント内チェック（異なるイベントの車両は比較不可→警告表示/フォールバック）
- [ ] 画像URL未解決時のプレースホルダ維持

## パフォーマンス/品質
- [ ] 2系列限定のデータ生成（不要なクラス全件の走査を避ける）
- [ ] スケール共有・再計算抑制（必要に応じて局所的にキャッシュ）

## 検証/受け入れ
- [ ] AC-01: 単体表示の見た目/値が現行と同一
- [ ] AC-02: 2台時に各ブロックが2系列で描画
- [ ] AC-03: SwapでA/Bが正しく入れ替わる
- [ ] AC-04: ハーフモーダルでレイアウト崩れなし

## 移行/公開
- [ ] 既存公開APIの破壊なし（`CarDetails.view` 維持）
- [ ] 新モジュールの公開範囲確認（`exposing`）とドキュメンテーション
