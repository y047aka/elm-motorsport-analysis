# Design Document

## 概要
CarDetailsにて、任意の2台の車両を並列比較できる新UIを実装する。

## アーキテクチャ方針
- 採用: 方式B「新モジュール導入」
  - 新規: `Motorsport.Widget.CarDetails.Compare`（以下、Compare）
  - 目的: 既存 `Motorsport.Widget.CarDetails` を変更最小で維持しつつ、比較専用のProps/描画・操作を提供。
- 既存の `CarDetails.view : Props -> Html msg` は変更しない。
- HalfModal などの呼び出し側で、UI操作に応じて `CarDetails.view` と `CarDetails.Compare.view` を切替。

## 公開インターフェース（案）
```elm
module Motorsport.Widget.CarDetails.Compare exposing (Props, Alignment(..), view)

type Alignment = ByLap | ByElapsedTime

type alias Props =
    { eventSummary : EventSummary
    , viewModel : ViewModel
    , clock : Clock.Model
    , analysis : Analysis
    , carA : ViewModelItem
    , carB : ViewModelItem
    , alignment : Alignment
    }

view : Props -> Html msg
```

- `Props` は `CarDetails.Props` と共通項を持つが、`selectedCar` の代わりに `carA`/`carB` を受ける。
- `alignment` 切替はチャートX軸の基準を変更（周回番号/経過時間）。

## UI構成（Compare）
- Header
  - 左右に `carA` / `carB` の車番・ドライバー・チーム・画像。
  - 中央に操作: `Swap`（A/B入替）, `Clear B`（単体表示への復帰）, 凡例（色/線種）。
- KPI Row
  - Current Lap（AとBを2列で数値比較）
  - Last Lap（同上）
- Charts
  - Histogram: 2系列（同一X軸）をオーバーレイ。透明度と色で区別。
  - Position Progression: 2系列ライン（Aは実線、Bは点線）。
  - Lap Time Progression: 2系列ライン。
- モバイル最適化
  - スタック表示（1カラム）＋タブ/トグルでチャート切替。
  - Headerの操作はアイコン＋短ラベル。

## カラールール/凡例
- 既存 `Manufacturer.toColorWithFallback` を両車に適用。

## データ取得・前提
- 同一イベント内の車両のみ比較対象（URL/導線でガード）。
- 画像は `Data.Series.carImageUrl_Wec season carNumber` を再利用。
- 数値系は既存 `Analysis`, `ViewModel`, `ViewModelItem` を使用。

## 実装計画（モジュール分割）
1) `Motorsport.Widget.CarDetails.Compare`（エントリ）
   - Header/KPI/Charts をレイアウト。
   - Swap/Clear/Alignment UI とハンドラ（親側でMsgを扱わない方針のため、Compare内部は無状態。ハンドラは`onClick`等で親へ委譲、またはNoOp）。
2) `Motorsport.Widget.CarDetails.Compare.Histogram2`
   - 既存 `Motorsport.Chart.Histogram` を参考に、2系列重ね描画を行う薄いラッパー（同一`Analysis`を使いX軸揃え）。
3) `Motorsport.Widget.CarDetails.Compare.PositionProgression2`
   - 既存 `PositionProgression` のロジックを2系列用に簡略化（対象2台のみの`PositionSeries`生成）。
4) `Motorsport.Widget.CarDetails.Compare.LapTimeProgression2`
   - 既存 `LapTimeProgression` を参考に、対象2台の `Lap` 列のみ描画。

備考: 既存モジュールの公開APIを増やすのではなく、新規`*2`モジュールで必要箇所のみ移植しスリム化。既存の全クラス表示など重い処理を避け、2系列に限定することで描画負荷も低減。

## 統合
- `compare` が妥当な車番かつ同一イベント内で存在する場合は Compare を選択、それ以外は既存CarDetails単体表示。
- 画面内の「+比較」UIは、B未選択時は車両ピッカー（Leaderboard側の行アクション or サジェスト）をトリガー。

## エラー処理
- 2台のうち片方が無効（データ欠落/異イベント）の場合は単体表示へフォールバックし、ヘッダに警告を表示。
- 画像未解決時は空表示（既存踏襲）。

## 性能・品質
- 2系列限定とし、クラス全体描画を行わない。
- 座標/スケールは共有化し、変換関数の再計算を抑制。

## テレメトリ（任意）
- Compare開始/解除、Swap、Alignment切替の発火ポイントをプレースホルダ関数で用意（送信先は未定）。

## 受け入れ基準トレーサビリティ
- AC-01〜04（requirements.md）に対応：
  - Compare導入による非破壊統合、2系列描画、Swap/Clear/URLクエリ、モバイル最適化、色以外の区別を設計で満たす。
