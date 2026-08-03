# 引き継ぎ: Motorsport.ViewModel のコンセプト再構成

対象リポジトリ: `y047aka/elm-motorsport-analysis`
ブランチ: `claude/motorsport-viewmodel-concept-mtvj9n`
基点: `709dfa0`（`48b09fc` の上に 1 コミット）

---

## 0. 貼り付け用プロンプト

新しいローカルセッションの冒頭にそのまま貼ってください。

> `claude/motorsport-viewmodel-concept-mtvj9n` ブランチで、`Motorsport.ViewModel` の
> 再構成を続けます。リポジトリ直下の `HANDOFF-viewmodel.md`（またはこの内容）に
> 調査結果と計画があります。まず読んでから、「4. 残作業」のステップ 2 から着手して
> ください。
>
> 前のセッションはリモート環境で走っていて `package.elm-lang.org` が遮断されていた
> ため、コミット済みの `709dfa0` を含め**一度もコンパイル検証されていません**。
> 最初に `nix run .#test` と `nix run .#build` を通してベースラインを確認してから
> 進めてください。
>
> 各ステップの終わりに必ず `nix run .#format` → `nix run .#test` →
> `nix run .#review-package` を回し、通ってからコミットしてください。

---

## 1. 何を解こうとしているか

`Motorsport.ViewModel` は「Race のリプレイ結果を view 関数が扱いやすい形に転写する」
ための層、という位置づけだった。しかし実装はそうなっていない。

`ViewModel.compute` → `Standings.compute` が実際に行っているのは:

- レースを時刻でサンプリングする（`carStateAt`）
- 誰が前にいるかを決める（`Ordering.runningOrder`）
- ギャップとクラス内順位を計算する（`Gap.at`, `positionsInClassByCarNumber`）
- BestTimes と突き合わせて評価する（`rateTime`）

これらはどれも「view 層を差し替えても結果が変わらない」値で、転写ではない。
**中間層が欠けていて ViewModel が兼務している**というのが診断。

```
Race（不動のデータ + インデックス）
  ↓  ← ここが無い
Race.Snapshot（Race × Clock のサンプリング結果。まだドメインの値）
  ↓
ViewModel（描画都合だけ）
```

`Race.elm` の冒頭コメント自身が
"what the cars are doing at that moment is derived from the two, in `ViewModel.Standings`"
と書いていて、この導出先として ViewModel を名指ししているのが根本。

---

## 2. 再導出不要な調査結果

### 2.1 `Entry` 23 フィールドの内訳

| 分類 | 数 | 例 |
| --- | --- | --- |
| A. 時刻によるサンプリング | 9 | `status`, `lapsCompleted`, `currentLapTime/Best/Sectors/MiniSectors`, `currentLapElapsed`, `currentDriver` |
| B. 車間の相互計算 | 4 | `position`, `positionInClass`, `gapToLeader`, `intervalToAhead` |
| C. BestTimes との比較評価 | 6 | `currentLapRated`, `lastLapRated`, `bestLapRated`, `lastLapSectors`, `lastLapMiniSectors`, `currentLapSectorStates.rated` |
| D. 描画用の幾何・数値 | 4 | `sector`, `miniSector`, `currentLapProgress`, `currentLapSectorStates.progress` |
| E. 表示スタイル | 1 | `classColor` |
| F. 純粋な転写 | **1** | `metadata` |

A・B・C（19/23）は Snapshot 側に属する。ViewModel に残るのは D・E の 5 つだけ。

### 2.2 view 側の行き先

| モジュール | 読んでいるもの | 行き先 |
| --- | --- | --- |
| `Chart/GapChart.elm:74-80` | `metadata` + LapHistory | Snapshot |
| `Widget/Compare/PositionProgression.elm:64-71` | `metadata` + LapHistory + `toClassList` | Snapshot |
| `Widget/Compare/Distribution.elm:50-63` | `metadata`, `lastLapRated.time`, LapHistory | Snapshot |
| `Widget/SelectedCarsStrip/RivalGapSparkline.elm` | Entry + LapHistory | Snapshot |
| `Widget/Compare/CarSummary.elm:204-205` | `gapToLeader`, `intervalToAhead` | Snapshot |
| `Widget/LiveStandings.elm:113-127` | `position`, `currentDriver`, `intervalToAhead`, `status` | Snapshot |
| `Widget/Leaderboard.elm:341,583,646` | `*Rated`, `*Sectors`, BestTimes | Snapshot |
| `Widget/Compare/CarSelector.elm` | Entry, ClassInfo, Standings | Snapshot |
| `Widget/CarNumberBadge.elm:19-57` | `metadata` のみ | **`Car.Metadata`**（Snapshot すら不要） |
| `Chart/Tracker.elm:354` + `Tracker/Config.elm:171-183` | `classColor`, `currentLapProgress`, `sector`, `miniSector` | ViewModel |
| `Widget/SectorAndLaps.elm:82-151` | `currentLapSectorStates` | ViewModel |
| `Widget/SelectedCarsStrip/CarCard.elm:135` | `classColor` | ViewModel |

**12 中 9 が ViewModel を参照しなくなる。**

### 2.3 すでに ViewModel を経由していない view（前例）

- `app/src/View/RaceEvents.elm:22-29` — `replay.race.timelineEvents`, `replay.playback`
- `app/src/View/PlaybackControls.elm:92-98` — `replay.playback`, `race.lapTotal`
- `app/src/Page/Debug.elm:80-136` — `race.cars` から自前で `Standings.fromLaps` を組み、
  ViewModel からは `bestTimes` しか取らない

「view が Race を直接見る」ことは設計として既に許容されている。

### 2.4 `Scope` は設計ではなくブートストラップの都合

`ViewModel.elm:37` の `WholeRace` / `UpToElapsed`:

- `Shared.elm:44,153` — 初期化時とロード完了時は `WholeRace`
- `Shared.elm:125` — 以降の `ReplayMsg` はすべて `UpToElapsed`
- 唯一 `WholeRace` を必要としている Debug ページは `viewModel.standings` を使っていない

「ロード直後は clock=0 だが Debug ページに全体統計を出したい」という都合。
副作用として、Debug ページのスライダーを一度動かすと `fastestLapTime` の意味が
「レース全体の最速」から「その時点までの最速」に静かに切り替わる。

### 2.5 `Standings.fromLaps` / `fromList` は偽装

`Standings.elm:173` は `metadata.carNumber` にラップ番号の文字列を詰め、
`gapToLeader = Gap.none`、`currentLapElapsed = 0` を埋めている。
Debug ページのために「レースでない何か」を Standings に偽装している。
`Entry` が 23 フィールドの塊であることの代償。

---

## 3. 実施済み（コミット `709dfa0`）

`LapHistory` を `Motorsport/ViewModel/` → `Motorsport/Race/` へ移動。

- 型もシグネチャも一切変えていない純粋なモジュール移動
- 移動理由: 生の `Lap` に clock を適用しただけで、view 層を差し替えても出力が変わらない
- モジュールドキュメントを書き換え（旧文は "belongs to the computed-model layer" と自認していた）
- import 8 箇所を更新し、辞書順も維持
- `CLAUDE.md` の Architecture 節に `Race/` と `ViewModel/` の振り分け基準を追記

**⚠️ このコミットはコンパイル検証されていない。** リモート環境で
`package.elm-lang.org` がエグレスポリシーで遮断されており、elm が依存解決できなかった。
ローカルで最初に `nix run .#test` を通すこと。

---

## 4. 残作業

### ステップ 2: `Motorsport/Race/Snapshot.elm` を新設（本丸）

`Standings.compute` から以下を移設する。

移設対象（すべて `package/src/Motorsport/ViewModel/Standings.elm`）:

| 現在地 | 内容 |
| --- | --- |
| `:250` `CarState` | Snapshot の要素型へ（`CarAt` などに改名） |
| `:262` `carStateAt` | 時刻サンプリング |
| `:67` `Ordering.runningOrder` 呼び出し | 走行順の確定 |
| `:405` `positionsInClassByCarNumber` | クラス内順位 |
| `:363` `init_timing` | currentLapElapsed / sector / miniSector / gap |
| `:395` `gapTo` | ギャップ |
| `:447` `closeIntervalThreshold` + `:451` `groupCarsByCloseIntervals` | バトル判定 |

想定シグネチャ:

```elm
module Motorsport.Race.Snapshot exposing (Snapshot, CarAt, at, toList, toClassList, leader, lapCount, elapsed)

at : BestTimes.Snapshot -> { elapsed : Instant } -> Race -> Snapshot
```

`Standings` が持っている `elapsed` / `lapCount` / `entries` / `entriesByClass` の
構造はそのまま Snapshot に移せる（`Standings.elm:42-53`）。

注意:
- `init_timing` は snake_case のまま残っている。移設のついでに改名する
- `CarState` は `Gap.Competitor` を拡張した形で、`laps` と `currentLap` を
  トップレベルに置く必要がある（`Standings.elm:241-248` のコメント参照）。
  この制約は Snapshot 側でも維持すること

### ステップ 3: 評価（C）を Snapshot へ

`rateTime`（`:289`）、`extractSectorPerformance`（`:335`）、
`extractMiniSectorPerformance`（`:340`）を Snapshot 側へ。

`extractCurrentSectorStates`（`:302`）だけは progress（D）と rated（C）が
混ざっているので分割が必要。`CurrentSectorStates`（`Entry.elm:73`）の
`{ progress, rated }` を、rated は Snapshot、progress は ViewModel に分ける。

`BestTimes` は「Race と ViewModel のどちらにも属さない」位置づけ（CLAUDE.md 記載）
なので、Snapshot が読む形にして問題ない。

### ステップ 4: ViewModel を薄くする

ここまでで ViewModel に残るのは:

- `classColor` — `(Class.toColor metadata.class).value`（`Standings.elm:111`）
- `currentLapProgress` — `Tracker/Config.computeProgress` からのみ使用
- `sector` / `miniSector` — `Lap.progressAt` / `Lap.miniSectorProgressAt` の呼び出し結果
- `currentLapSectorStates.progress`

参照するのは Tracker(+Config) / SectorAndLaps / CarCard の 3 モジュールのみ。

### ステップ 5: 判断ポイント — ViewModel を畳むか

残りが 5 フィールド・3 モジュールなら、層として立てる価値は薄い。
レコードのフィールドではなく Snapshot 上の関数として提供する案:

```elm
Snapshot.lapProgressOf : CarAt -> Float
-- classColor は view 側で Class.toColor を直接呼ぶ
```

**この判断は計測してから決める**（下の「注意点」参照）。ここで一度止めて相談するのが良い。

### ステップ 6: 付随整理

- `Widget/CarNumberBadge.elm` を `Entry` ではなく `Car.Metadata` 受けにする
- `Standings.fromLaps` / `fromList` の扱い。Debug ページ専用の型に切り出すか、
  `Entry` が薄くなった結果として偽装が減るかを見る
- `Scope`（`ViewModel.elm:37`）の再設計。「Snapshot をどの時刻で取るか」に還元できるはず
- `app/src/Page/Debug.elm:115-127` の `fastestLapTime` 表示の意味が
  スライダー操作で切り替わる件を、Scope 再設計と合わせて解消する

---

## 5. 検証

各ステップの終わりに:

```bash
nix run .#format          # elm-format
nix run .#test            # elm-verify-examples + elm-test
nix run .#review-package  # elm-review
nix run .#build           # 本番ビルド
```

view の見た目が変わっていないことの確認:

```bash
nix run .#test-vrt        # Playwright VRT（ローカルは 1% トレランス）
```

VRT はこのリファクタの安全網として重要。**ステップ 2 に入る前に一度 VRT を通して
ベースラインを確定**しておくこと。

---

## 6. 注意点・落とし穴

### Html.Lazy への依存

`Entry` が「計算済みの安定した値のレコード」であることに lazy が依存している。

- `Widget/LiveStandings.elm:77` — `Lazy.lazy3 carRow props.popoverTarget props.onSelectCar item`
  → `item` の参照同一性で効いている。`Entry` を `CarAt` に置き換えても等価
- `Chart/Tracker.elm:354` — `Lazy.lazy2 carMarker car.positionInClass car.classColor`
  → `classColor : String` を渡している。`car.metadata.class` に変えるとカスタム型の
  参照比較になる。同じ Snapshot 内なら安定するが、Snapshot を毎フレーム作り直す以上
  どちらにせよ lazy はフレームごとに 1 回は貫通する

`Widget/Leaderboard.elm:341,583,646` は拡張レコード
`{ a | lastLapRated : Maybe RatedTime, ... }` で部分的にしか要求していないので、
`Entry` の分解自体はやりやすい。

### per-frame コストの計測手段が壊れている

`package/benchmark/CarsAtBenchmark.elm` が削除済みの
`Motorsport.Car` / `Motorsport.Race.Entrant` / `Race.fromEntrants` を参照している
（`84a87fd` の再構成で消滅）。

- **`elm-test` には影響しない。** Elm は到達可能なモジュールしかコンパイルせず、
  `package/tests/` のどのテストもこれを import していない
- 壊れているのは `pnpm --filter package benchmark` を実行したときだけ
- ただしこのベンチマークの計測対象がまさに「毎フレームの導出コスト」なので、
  **ステップ 5 の判断をするなら先に復旧させる必要がある**
- `Fixture.Generated` は gitignore されていて `node generate-fixture.mjs` で生成される
  （`app/static/wec/2025/fuji_6h_laps.json` が入力）

### elm-verify-examples

docstring 内の例（`Ordering.elm:41` など）が実行対象。シグネチャを変えたら
docstring の例も追随させること。

### 再生は毎フレーム走る

`app/src/Page/Wec/Event.elm:150-156` で `onAnimationFrame` ごとに
`ViewModel.compute` が呼ばれ、LiveStandings / Tracker / SelectedCarsStrip /
CarDetailPopover の 4 箇所が同じ結果を読む。
「一度計算して共有する層」を消すと同じソートとギャップ計算が 4 回走る。
これが「ViewModel（または Snapshot）という層を残す」最大の根拠。

---

## 7. 却下した案とその理由

**「ViewModel を捨てて Race の各型に文字列出力を持たせる」** — 前提が成立しない。

- 文字列化はすでに view 側にある。`Gap.toString`（`Widget/Compare/CarSummary.elm:204`,
  `Widget/LiveStandings.elm:120`）、`Duration.toString`（`Widget/SectorAndLaps.elm:122`）。
  ViewModel は文字列化層ではないので、文字列出力を足しても仕事が一つも減らない
- 車間の計算（`runningOrder`, `gapToLeader`, `intervalToAhead`, `positionInClass`）は
  全車を並べて初めて決まる。`Car` にも `Lap` にもメソッドとして生やせない
- per-frame の計算共有が失われる（上記）

ただし「23 フィールドを毎フレーム全部作る必要はない」という指摘は正しく、
それはステップ 4-5 で回収する。
