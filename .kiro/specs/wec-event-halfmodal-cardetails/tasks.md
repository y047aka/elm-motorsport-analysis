# Implementation Plan

- [ ] 1. ハーフモーダルの表示内容を CarDetails に置換
  - HalfModal 内の主要表示を CarDetails に切り替え、既存の Leaderboard 表示は無効化（削除はしない）。
  - 描画は遅延評価で包み、初期レンダーのコストと再描画を抑制する。
  - サイドバーと同等の情報密度・表示順を維持し、差分は最小化する。
  - _Requirements: Goals、Acceptance 1、User Story 1_

- [ ] 1.1 初期表示と描画条件の定義
  - モーダル開閉状態に連動して CarDetails を表示する条件を定義する。
  - 選択車両が未設定のときは、その時点の　1位車両を初期表示とする。
  - 遅延描画（Lazy）を適用し、開閉トグル時のパフォーマンスを担保する。
  - _Requirements: Assumptions、Open Question #1（解決:1位表示）、Acceptance 1_

- [ ] 1.2 データ束縛とフォールバックの統一
  - サイドバー版と同じデータ経路・型を用いて CarDetails に値を束縛する。
  - 欠損フィールドは "N/A" などのフォールバック表記で統一する。
  - 空データ時の最小限のプレースホルダーと案内文を表示する。
  - _Requirements: Data & API、Error & Empty States、Acceptance 3_

- [ ] 2. 選択車両ステートの同期（サイドバー/ハーフモーダル）
  - 単一ソースの選択ステートに集約し、双方のビューで矛盾なく参照できるようにする。
  - 選択変更が双方に即時反映されることを保証する（双方向同期）。
  - _Requirements: Goals、User Story 2、Acceptance 2_

- [ ] 2.1 選択変更イベントの伝播と整合
  - 車両選択メッセージを通じて状態を更新し、両ビューが同一の選択を示すようにする。
  - 外部起点（リスト/地図など）での選択変更も同じ経路で反映する。
  - _Requirements: Goals、User Story 2、Assumptions_

- [ ] 2.2 初期選択と再選択時の更新ロジック
  - 初期表示時の自動選択（1 位）と、再選択時の更新・再描画を一貫した規則で処理する。
  - 競合条件（短時間での連続選択）でも整合が崩れないようにする。
  - _Requirements: Goals、Acceptance 2_

- [ ] 3. ローディング/エラー/空状態の UI 実装
  - データ取得中はローディングインジケータを表示し、ちらつきを抑える。
  - エラー時は簡潔なメッセージを提示する。
    - 再試行導線は不要
  - 空データ時はプレースホルダーと案内文を表示する（サイドバーと整合）。
  - _Requirements: Error & Empty States、Acceptance 3_

- [ ] 3.1 ローディング表示とスケルトン
  - 必要に応じてスケルトン/プレースホルダーで主要レイアウトを保持する。
  - _Requirements: Error & Empty States_

- [ ] 3.2 エラー表示と再試行ハンドリング
  - 取得失敗時に失敗理由を簡潔に説明する。
    - 再試行可能な UI の提示は不要
  - _Requirements: Error & Empty States、Acceptance 3_

- [ ] 3.3 空状態のプレースホルダー統一
  - サイドバー版と文言・表記ゆれを統一する（"N/A" など）。
  - _Requirements: Data & API、Error & Empty States_

- [ ] 4. 結合・検証・テスト
  - 主要ユースケース（初期表示、選択切替、開閉トグル、例外系）のスモークテストを用意する。
  - サイドバーとハーフモーダルの表示内容が一致することを検証する。
  - 遅延描画により体感性能が劣化していないことを確認する。
  - _Requirements: Acceptance 1–3、User Stories_

- [ ] 4.1 スモーク/回帰テストの追加
  - 初期表示の 1 位選択、選択変更の反映、空/エラー表示の確認を自動化する。
  - _Requirements: Acceptance 1–3_

- [ ] 4.2 同期整合とレンダリングコストの検証
  - 双方向同期の整合と再描画頻度を計測し、過剰レンダリングを抑制する。
  - _Requirements: Goals、Acceptance 2_
