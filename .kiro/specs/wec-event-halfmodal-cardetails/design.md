# Design Document

## Overview
- ハーフモーダル（`UI.HalfModal`）に表示している `Leaderboard` を、右サイドバーと同等の `CarDetails` に置換する。
- 既存の選択車両ステート（`selectedCar : Maybe String`）を用い、サイドバーとハーフモーダルの `CarDetails` を同期。

## Affected Modules
- `app/app/Route/Wec/Season_/Event_.elm`
- `app/src/UI/HalfModal.elm`（A11y拡張を行う場合）
- `Motorsport.Widget.CarDetails`（再利用のみ、改修は原則不要）

## Data Flow & State
- 単一ソースの選択車両：`Model.selectedCar : Maybe String`（既存）
- `selectedCarItem : Maybe ViewModelItem` を `view` 内で計算し、`CarDetails.view` に渡す（サイドバーと同様）。
- `CarSelected String` メッセージで双方（サイドバー/ハーフモーダル）の `CarDetails` が同期更新。

## Feature Flag
- Feature Flagは使用せず、一度の改修で最終形を目指す

## View Changes (Pseudo‑Diff)
- 対象: `app/app/Route/Wec/Season_/Event_.elm`
- 置換箇所（概略）：
  ```elm
  [ HalfModal.view
      { isOpen = isLeaderboardModalOpen
      , onToggle = ToggleLeaderboardModal
      , children =
          [ if featureFlagHalfModalCarDetails then
              -- New: CarDetails in HalfModal
              Lazy.lazy CarDetails.view
                { eventSummary = eventSummary
                , viewModel = viewModel
                , clock = raceControl.clock
                , selectedCar = selectedCarItem
                , analysis = analysis
                }
            else
              -- Old: Leaderboard
              Leaderboard.view (config eventSummary.season analysis) leaderboardState viewModel
          ]
      }
  ]
  ```

## Performance
- `CarDetails.view` は比較的重い可能性があるため、`Lazy.lazy` でラップ。

## Testing Plan（実装前提の観点）
- 単体: HalfModal に `CarDetails` が描画される条件分岐（フラグON/OFF）。

## Risks & Mitigations
- UI重複で視認性/性能低下 → レスポンシブで折りたたみ、`Lazy.lazy` 適用。
- 既存 Le Mans 24h 特例の置換影響 → Config差分などがなくなるため、特例扱いを廃止できる見込み

## Tasks（次フェーズで詳細化）
1. `Event_.elm` の HalfModal 子要素を `CarDetails.view` へ置換（`Lazy.lazy` 適用）。
2. （推奨）`UI.HalfModal` に `attrs` 追加し、`role/aria` を付与。
3. 受け入れ条件に沿った動作確認とレイアウト調整。

---
本設計は要件承認済み前提です。承認後、タスク分解（/kiro-spec-tasks）へ進みます。
