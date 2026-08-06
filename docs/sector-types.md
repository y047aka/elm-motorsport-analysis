# Sector / MiniSector を格納する型の整理（検討）

`Motorsport` 配下で Sector と MiniSector のデータを持つ型を棚卸しし、どこに歪みが
あるか、カスタム型で状態を表現すると何が改善するかを検討した記録。

実装は含まない。各提案には根拠となる現行コードの位置と、変更が及ぶ範囲を添えてある。

---

## 1. 現状の棚卸し

Sector / MiniSector に関わる型は、大きく 4 層に分かれている。

### 1.1 識別子と「区間ごとの値」の入れ物

| 型 | 場所 | 中身 |
| --- | --- | --- |
| `Sector(..)` | `Motorsport/Sector.elm:32` | `S1 \| S2 \| S3` |
| `BySector a` | `Motorsport/Sector.elm:120` | `{ s1, s2, s3 }` の透過レコード |
| `LeMans2025MiniSector(..)` | `Motorsport/Circuit/LeMans.elm:28` | 15 個の構築子 |
| `ByMiniSector a` | `Motorsport/Circuit/LeMans.elm:50` | 15 フィールドの透過レコード |

`BySector` には `all` / `compare` / `initialize` / `get` / `map2` / `values` / `toList` が
揃っている。`ByMiniSector` は `initialize` / `get` / `map2` / `values` / `compare` のみで、
`all`（＝`miniSectorOrder`）と `toList` は名前も所在も揃っていない。

### 1.2 ラップが持つ計測値

| 型 | 場所 | 中身 |
| --- | --- | --- |
| `Lap.SectorTime` | `Motorsport/Lap.elm:66` | `{ time : Maybe Duration, personalBest : Maybe Duration }` |
| `Lap.SectorTimes` | `Motorsport/Lap.elm:74` | `BySector SectorTime` |
| `Lap.MiniSectorData` | `Motorsport/Lap.elm:82` | `{ time, elapsed, best : Maybe Duration }` |
| `Lap.MiniSectors` | `Motorsport/Lap.elm:78` | `ByMiniSector MiniSectorData` |
| `Lap.miniSectors` | `Motorsport/Lap.elm:54` | `Maybe MiniSectors` |

### 1.3 ラップを幾何として切ったもの

| 型 | 場所 | 中身 |
| --- | --- | --- |
| `Lap.Segment` | `Motorsport/Lap.elm:239` | `{ start : Instant, time : Duration }` |
| `Lap.SectorProgress` | `Motorsport/Lap.elm:321` | `{ sector : Sector, progress : Float }` |
| `Lap.MiniSectorProgress` | `Motorsport/Lap.elm:396` | `{ miniSector : LeMans2025MiniSector, progress : Float }` |

セクター側は `segments : Lap -> BySector Segment`（`Lap.elm:265`）で一度に切り出せる。
ミニセクター側に対応するものはなく、`currentMiniSector`（`Lap.elm:351`）が呼ばれる
たびに `foldl` で区間列を組み立て直している。

### 1.4 評価済み・瞬間の状態

| 型 | 場所 | 中身 |
| --- | --- | --- |
| `Performance.SectorPerformance` | `Lap/Performance.elm:69` | `BySector (Maybe RatedTime)` |
| `Performance.MiniSectorPerformance` | `Lap/Performance.elm:87` | `ByMiniSector (Maybe RatedTime)` |
| `Snapshot.CurrentSectorStates` | `Race/Snapshot.elm:189` | `BySector { progress : Float, rated : Maybe RatedTime }` |
| `Snapshot.CurrentMiniSectorStates` | `Race/Snapshot.elm:200` | `ByMiniSector { progress : Float, rated : Maybe RatedTime }` |
| `BestTimes.ByRecord` | `BestTimes.elm:95` | `fastestSectors : BySector a` / `fastestMiniSectors : ByMiniSector a` |
| `Tracker.Config.MiniSectorData(..)` | `Chart/Tracker/Config.elm:38` | `WithMiniSectors (List _) \| NoMiniSectors` |

---

## 2. 課題

### 2.1 「区間の進行状況」が `Float` に潰れている ★最有力

`{ progress : Float, rated : Maybe RatedTime }`（`Race/Snapshot.elm:189, 200`）は、
値としては `Float × Maybe RatedTime` の全組み合わせを許すが、実際に意味があるのは
3 状態しかない。

- まだ入っていない（`progress = 0`、`rated` は無意味）
- 走行中（`0 < progress < 1`、`rated` は無意味）
- 通過済み（`progress = 1`、`rated` があれば色が付く）

そして読み手は全員、この 3 状態を `progress < 1` という**再構成**で取り出している。

- `Widget/Leaderboard.elm:154` — `if progress < 1 then 白の部分塗り else rated の色`
- `Widget/Leaderboard.elm:264` — 同じ判定を別のセル描画で再実装
- `Widget/SectorAndLaps.elm:146` — 同じ判定を 3 度目に再実装

生成側も、状態を `Float` に符号化するために不自然な値を書いている。

- `Race/Snapshot.elm:255-264` — `LT → 1` / `EQ → 進行度` / `GT → 0`
- `Race/Snapshot.elm:283-297` — 「ラップ最後のミニセクターより後」を `Nothing → 1`
  と書き、「全部通過済み」を `1` という数字で表している
- `app/src/Page/Debug.elm:239` — 進行という概念自体が無い画面で `progress = 1` を
  ダミーとして埋めている（`Leaderboard.sectorTimeColumn` の引数が要求するため）

`rated` は「通過済みだがソースにタイムが無い」を表すためだけの `Maybe` なのに、
未通過・走行中でも型上は指定できてしまう。ここが本件で最もカスタム型が効く箇所。

### 2.2 `Maybe MiniSectors` が 2 つの意味を兼ねている

`Lap.miniSectors : Maybe MiniSectors`（`Lap.elm:54`）の `Nothing` は、

1. ミニセクターを持たないサーキット（ル・マン以外）
2. ル・マンだがそのラップの計測が欠けている

を区別しない。実際、`app/src/Data/Wec/Laps.elm:197` は常に `Nothing` を、
`Race/TimelineEvent.elm:300` は `optional` を書いており、両者は別の理由で `Nothing`
になる。

さらに「サーキットがミニセクターを持つか」は本来レース全体の性質なのに、`Race`
（`Motorsport/Race.elm:45`）はサーキットを持っていない。そのため描画側が
`Chart/Tracker.elm:107-115` で `season == 2025 && eventName == "24 Hours of Le Mans"`
という文字列一致からレイアウトを引き当てている。ラップ 1 本ごとの `Maybe` は、
この欠けた情報の代用になっている。

### 2.3 `SectorTime` と `MiniSectorData` が非対称

同じ「区間の計測値」なのに形も名前も揃っていない。

| | セクター | ミニセクター |
| --- | --- | --- |
| 型名 | `SectorTime` | `MiniSectorData`（`Data` は何も言っていない） |
| 自己ベスト | `personalBest` | `best` |
| 累積 | 無し（`segments` が導出） | `elapsed` を保持 |

`elapsed` を持つこと自体は妥当で、これは冗長ではない。`time` が欠けたミニセクター
があっても `elapsed` があれば位置を復元できるからで、セクター側の
`segments`（`Lap.elm:265`）が「タイム無しの区間は長さ 0」として押し流しているのに
対し、ミニセクター側はそれを避けられる。問題は保持していることではなく、
`elapsed` が「ラップ先頭からの累積」だと型が言っていないこと、そして先頭区間の
起点が `miniSectorStartElapsed` の `SCL2 -> Just 0`（`Lap.elm:475-478`）という
構築子名の直書きで特別扱いされていることにある。

### 2.4 `ByMiniSector` の API が `BySector` に揃っておらず、順序が線形探索

`Sector.compare` は `toIndex` を `case` 式で書いており（`Sector.elm:67-77`）、
網羅性がコンパイラに守られる。ミニセクター側の `toIndex` は
`List.Extra.elemIndex >> Maybe.withDefault 0` で（`Circuit/LeMans.elm:288-292`、
および `Lap.elm:445-449` に同じものが二重にある）、次の 2 つの問題を持つ。

- **黙って誤答する**：`Maybe.withDefault 0` は「見つからなければ先頭扱い」。
  `miniSectorOrder` は `layout.sectors` の連結（`Circuit/LeMans.elm:174-176`）なので、
  レイアウトから 1 つ落とすと該当ミニセクターは静かに `SCL2` と同順位になる。
  構築子の網羅性が効かない書き方なので、コンパイラは何も言わない。
- **フレームあたりのコストが線形探索**：`Race/Snapshot.elm:286` の
  `LeMans.compare` は 1 台 1 フレームにつき 15 回呼ばれ、各回が 15 要素の走査を伴う。
  加えて `Lap.compareLapsInSameSector`（`Lap.elm:169`）は走行順ソートの比較関数の
  中でこれを呼ぶ。

`toIndex` を `case` 式にすれば両方とも消える。`Sector` 側と同じ書き方に揃えるだけ。

### 2.5 `LeMans2025MiniSector` がドメイン層に焼き付いている

`Circuit.Layout` は `miniSector` を型引数に取る総称型（`Circuit.elm:38`）だが、その
恩恵を受けているのは `Circuit.elm` 内だけで、実際の保持側は全て具体型を直接 import
している。

- `Motorsport/Lap.elm:37`
- `Motorsport/BestTimes.elm:31`
- `Motorsport/Lap/Performance.elm:31`
- `Motorsport/Race/Snapshot.elm:43`

つまり「ミニセクターは 15 個で、名前は SCL2…FL」がドメインモデルの前提になっている。
2026 年のレイアウト変更や別サーキットのミニセクターを入れるとき、`Circuit` を総称に
した意図と衝突する。

### 2.6 ワイヤ形式の型が重複している

`Race/TimelineEvent.elm:320-343` が `MiniSectors` / `MiniSector` を独自に定義していて、
`Lap.MiniSectors` / `Lap.MiniSectorData` と構造は同じだが別の型。デコード結果が
たまたま構造的に一致するので通っている状態で、`LeMans.initialize` は使われていない。
`Lap.MiniSectorData` のフィールドを 1 つ増やすと、ここが黙って壊れる（正確には型
不一致で止まるが、修正箇所が 2 か所に散る）。

セクター側は `sectorsDecoder : Decoder Lap.SectorTimes`（`TimelineEvent.elm:306`）で
ドメイン型を直接組み立てており、こちらが正しい形。

### 2.7 名前の衝突

- `Lap.Segment`（時間区間）と、2.1 で導入したくなる「区間の状態」が同じ語を欲しがる
- `Lap.MiniSectorData`（計測値）と `Chart/Tracker/Config.MiniSectorData`（レイアウトの
  有無を表すカスタム型、`Config.elm:38`）が同名で別物

後者は既にこのリポジトリに「ミニセクターの有無をカスタム型で表す」前例がある、
という点で 2.2 の参考にもなる。

---

## 3. 提案

独立して入れられる順に並べてある。1 と 3 は局所的で効果が確実、4 は範囲が広い。

### 提案 1：区間の状態をカスタム型にする ★実施済み

`Motorsport.Lap.Performance` に置く（`RatedTime` を既に持ち、セクターとミニセクターの
両粒度から読まれる評価の型が集まっている場所であるため）。

```elm
{-| ある瞬間に、ラップの 1 区間がどう読めるか。

セクターにもミニセクターにも同じ 3 状態しかない。`Completed` の `Maybe` は
「通過したがソースにタイムが無い」を表し、他の 2 状態では指定できない。
-}
type SegmentState
    = NotEntered
    | InProgress Float
    | Completed (Maybe RatedTime)
```

`Race.Snapshot` 側：

```elm
type alias CurrentSectorStates =
    BySector SegmentState

type alias CurrentMiniSectorStates =
    ByMiniSector SegmentState
```

生成側（`Race/Snapshot.elm:250-301`）は `LT -> Completed rating` / `EQ -> InProgress p`
/ `GT -> NotEntered` に、`currentMiniSectorStates` の `Nothing -> 1` は
`Nothing -> Completed rating` になる。「ラップ最後のミニセクターより後は全区間通過済み」
という意図が `1` という数字ではなく構築子で書かれる。

読み手（`Leaderboard.elm:147`、`SectorAndLaps.elm:145`）は `progress < 1` の再構成を
やめて `case` になる。3 か所に散った同じ判定が型の定義 1 か所に集まる。

**表示は変わらない。** 現状 `NotEntered` は `progress = 0` として「白の幅 0%」を
描いており、`InProgress 0` と同じ見た目になっている。

`Leaderboard.sectorTimeColumn`（`Leaderboard.elm:248`）は `progress` をレコードの
フィールドとして要求しているために `Page/Debug.elm:239` にダミーの `1` を書かせて
いる。ここは `SegmentState` を取る形に変えると、Debug 画面は `Completed` を渡すだけ
になり、ダミーが消える。

**影響範囲**：`Race/Snapshot.elm`、`Lap/Performance.elm`、`Widget/Leaderboard.elm`、
`Widget/SectorAndLaps.elm`、`app/src/Page/Debug.elm`、
`tests/Motorsport/Race/SnapshotTest.elm`。

#### 実装して分かったこと

**(a) これは整理ではなく、保証の追加だった。** 旧 `Sector.map2` は未通過セクターにも
`rated` を詰めていた。リプレイデータなのでラップ全体のセクタータイムは最初から
存在し、まだ出していないタイムがビューから読める状態だった。読み手が誰も使って
いなかっただけで、型は何も止めていない。`NotEntered` / `InProgress` に payload を
持たせないことで、これがコンパイラの保証になる。`SnapshotTest` にその回帰テストを
足した（"carry no rating until the car is through them"）。

**(b) `progress == 1` が実際に起こる。** `Race/Snapshot.elm` の `readCurrentLap` と
`Lap.miniSectorProgressAt` はどちらも進行度を `min 1` にクランプしており、ラップ
終端を過ぎた時計は最終セグメントで**ちょうど 1** を返す。旧 `progress < 1` の判定は
これを「通過済み」側に落としていたので、素直に `EQ -> InProgress` と書くと配色が
変わる。この境界は `Performance.fromProgress` に閉じ込め、`>= 1` を `Completed` へ
寄せてある。呼び出し側は 1 が境界だと知らなくてよい。

**(c) 描画は不変。** `NotEntered` は旧実装で「白・幅 0%」を描いており、幅 0 の要素は
何も塗らない。VRT スナップショットの更新は不要。

### 提案 2：`toIndex` を `case` 式にする ★実施済み

`Circuit/LeMans.elm:288-292` を `Sector.toIndex`（`Sector.elm:67-77`）と同じ形に書き換え、
`Lap.elm:445-449` の重複を `LeMans` 側へ寄せて削除する。網羅性がコンパイラに戻り、
2.4 の「黙って先頭扱い」と毎フレームの線形探索が同時に消える。

あわせて `ByMiniSector` の API を `BySector` に揃える。

- `LeMans.all : List LeMans2025MiniSector`（現 `miniSectorOrder` の別名または改名）
- `LeMans.toList : ByMiniSector a -> List ( LeMans2025MiniSector, a )`
- `LeMans.toString`（現 `miniSectorToString`。モジュール名で既に修飾されているので
  `miniSector` の前置は冗長）

`miniSectorOrder` を `layout.sectors` の連結から導いている点（`Circuit/LeMans.elm:174-176`）
は、`all` を構築子の直書きにして `layout` 側をそれに合わせて検証する向きに反転させる
のが望ましい。順序が「レイアウトの副産物」ではなく「型の定義」になる。

#### 実装して分かったこと

**(a) 「黙って先頭扱い」は 2 か所あった。** `Circuit/LeMans.elm` の `toIndex` に加えて
`Lap.elm` に `miniSectorToIndex` という同じ実装のコピーがあり、こちらは走行順ソートの
比較関数から呼ばれていた。`LeMans.compare` に一本化して削除。

**(b) 手書きインデックスが持ち込む新しい失敗はテストで塞いだ。** `case` 式にすると
構築子の網羅性はコンパイラが守るが、**2 つの構築子に同じ番号を書く**ミスは通って
しまい、その 2 つは `EQ` になって互いに区別できなくなる。`LeMansTest` に
「相異なるミニセクターが `EQ` にならない」テストを置いた。順序そのものは
`List.sortWith compare (List.reverse all) == all` で押さえている。

**(c) `layout` との整合はテストに落とした。** 依存の向きを反転させた結果、`all` と
`layout.sectors` の連結が一致することは型では保証されない。`LeMansTest` の
「is `all`, cut into the three sectors and no more」がこれを検査する。落とす・重複
させる・別セクターへ動かす、のいずれもここで落ちる。

**(d) ついでに `Maybe` が 1 つ減った。** `miniSectorDefaultRatio` は
`List.Extra.find` の結果をそのまま返す `Maybe Float` で、呼び出し側
（`Chart/Tracker/Config.elm`）が `Maybe.withDefault 0` を書いていた。全構築子に
重みがある以上 `Nothing` は起こらないので、重み表を `case` 式にして
`defaultRatio : LeMans2025MiniSector -> Float` に。呼び出し側の
`withDefault 0`（＝ゼロ幅のトラックという、起こったら明らかにおかしい既定値）が
消えた。名前も `miniSector` の前置を落として揃えてある。

### 提案 3：ミニセクターも `Segment` に切り出す

セクター側の `segments : Lap -> BySector Segment`（`Lap.elm:265`）に対応する

```elm
miniSegments : Lap -> Maybe (ByMiniSector Segment)
```

を用意し、`currentMiniSector` はそれを `Sector.toList` と同じ形で走査する。これで
次が消える。

- `miniSectorStartElapsed` の `SCL2 -> Just 0` 特別扱い（`Lap.elm:473-481`）
- `miniSectorPrevious`（`Lap.elm:484-495`）
- `miniSectorToElapsed`（`Lap.elm:452-460`）
- `currentMiniSector` 内で毎回組み立て直している `foldl` の区間列（`Lap.elm:369-386`）

セクターとミニセクターが「区間に切って、時計を当てて、入っている区間を探す」という
同じ手順の 2 粒度になり、`Lap.elm` の後半 150 行が縮む。

`elapsed` を落とすことは**しない**（2.3 の通り、欠測を跨げる利点がある）。落とすのは
`elapsed` から起点を毎回逆算するコードのほう。

### 提案 4：計測値の型名を揃える ★実施済み

- `Lap.MiniSectorData` → `Lap.MiniSectorTime`（`SectorTime` と対にする）
- そのフィールド `best` → `personalBest`（`SectorTime` に合わせる。
  `Performance.ofMiniSectors` の `personalBest = miniSector.best`、
  `Lap/Performance.elm:96` の読み替えが消える）
- `elapsed` → `elapsedInLap` など、ラップ先頭からの累積であることを名前で言う
- `Race/TimelineEvent.elm:320-343` のワイヤ型を削除し、`LeMans.initialize` を使って
  `Lap.MiniSectors` を直接デコードする（`sectorsDecoder` と同じ形にする）

#### 実装して分かったこと

**(a) `LeMans.initialize` はデコーダには効かない。** `initialize` は
`(mini -> a) -> ByMiniSector a` なので、`a` が `Decoder x` のときに得られるのは
`ByMiniSector (Decoder x)` であって `Decoder (ByMiniSector x)` ではない。15 個を
畳む方法（`Decode.dict` 経由、あるいは関数を畳み込む形）はどれも「起こらないはずの
既定値」を 1 つ持ち込むので、これまで削ってきたものを増やすことになる。

採った形は、レコード型エイリアスの構築子をそのまま使う：
`Decode.succeed LeMans.ByMiniSector |> required "scl2" miniSectorTimeDecoder |> ...`。
15 行は残る（ワイヤ形式が実際に 15 キーなので当然）が、**型が 2 つから 1 つになり**、
`MiniSectorTime` にフィールドを足したときにデコーダはコンパイルが止まる。以前は
構造が偶然一致していただけで、片方だけ直しても気づけなかった。

**(b) パイプラインが検査できない 1 点はテストで塞いだ。** 15 段の
`|> required` は位置で対応するので、行を 1 つ入れ替えると隣のフィールドにキーが
入り、何も失敗しない。`TimelineEventTest` に「各キーが名前どおりのミニセクターに
入る」テストを追加した。15 個すべてに異なるタイムを与えて `LeMans.toList` で
読み戻すので、隣同士の取り違えも検出できる。

**(c) 名前の衝突（2.7）は自然に解消した。** `Lap.MiniSectorData` が
`MiniSectorTime` になったので、`Chart/Tracker/Config.MiniSectorData` はもう
紛らわしくない。この型自体は提案 5 で `Circuit` 側から導出できるようになるため、
今回は触っていない。

### 提案 5：ミニセクターの有無をサーキットに戻す（範囲が広い・要判断）

2.2 の本筋。`Race` にサーキット（またはレイアウト）を持たせ、
`Chart/Tracker.elm:107-115` の文字列一致を廃す。そのうえで

```elm
type MiniSectorTiming
    = NotMeasured              -- このサーキットは計測しない
    | Measured MiniSectors     -- 計測対象で、このラップのデータはこう
```

を `Lap` に持たせるか、あるいはミニセクターを `Lap` から外して
`Race` 側の別テーブルに置くか、の二択になる。

`MiniSectorTiming` は `Maybe MiniSectors` と同型なので、単体では名前が付くだけで
検査は強くならない。**サーキット情報を `Race` に載せる作業とセットで初めて意味を持つ**
（載せて初めて「ル・マンなのに `NotMeasured`」を不整合として扱える）ので、提案 5 は
一括で判断すべき塊として扱い、提案 1〜4 とは分けたほうがよい。

`Chart/Tracker/Config.MiniSectorData(..)`（`Config.elm:38`）は、この形を描画側だけで
先に実現した例になっている。提案 5 を入れるなら、この型は
`Circuit` 側の表現から導出できるようになり、名前の衝突（2.7）も解消する。

### 提案 6：ミニセクター型の抽象化（今回は見送り推奨）

2.5 の `LeMans2025MiniSector` 焼き付けを解くには、`Lap` / `BestTimes` /
`Performance` / `Race.Snapshot` を `miniSector` について総称にするか、
`Dict`／`List ( id, value )` に置き換えることになる。前者は `ByMiniSector` が具体的な
15 フィールドのレコードである以上、型クラス相当が無い Elm では
「`initialize` / `get` / `map2` の 3 関数を引き回すレコード」を全モジュールに通す形に
なり、読みやすさを大きく損なう。後者は `ByMiniSector` を透過レコードにしている
理由（`Circuit/LeMans.elm:46-49`、フィールド名で直接引ける）を捨てることになる。

ル・マン以外にミニセクターを持つデータが実際に入る時点で再検討するのが妥当で、
それまでは提案 2 の `all` / `toList` を揃えておくことで、その日の移行面積を小さく
しておくのが現実的。

---

## 4. 推奨する順序

| # | 提案 | 効果 | 範囲 | 状態 |
| --- | --- | --- | --- | --- |
| 1 | 提案 1（`SegmentState`） | 3 か所の `progress < 1` とダミー値が消える／未通過区間の評価が読めなくなる | Snapshot＋描画 3 モジュール | 実施済み |
| 2 | 提案 2（`toIndex` を `case` に、`ByMiniSector` の API 整備） | 誤答の芽を摘む＋毎フレームの線形探索を消す | `Circuit/LeMans.elm`, `Lap.elm`, `Chart/Tracker*` | 実施済み |
| 3 | 提案 4（命名とワイヤ型の統合） | 機械的、レビューが軽い | `Lap.elm`, `TimelineEvent.elm`, `Performance.elm` | 実施済み |
| 4 | 提案 3（`miniSegments`） | `Lap.elm` の後半が縮む | `Lap.elm` 内で完結 | 未着手 |
| 5 | 提案 5（サーキットを `Race` へ） | 2.2 の根治。要設計判断 | `Race`, `Tracker`, ローダ | 未着手 |

1〜4 は互いに独立で、それぞれ単独の PR にできる。5 は着手前に方針を決める必要がある。

## 5. 今回スコープ外としたもの

- `BySector` / `ByMiniSector` を不透明型にすること。`Sector.elm:112-118` が既に
  「守るべき不変条件が無く、同型 3 引数の構築子より名前付きフィールドのほうが
  安全」と結論を書いており、その判断を覆す材料は見つからなかった。
- `Sector(..)` を 3 構築子より多く／少なくできるようにすること。S1/S2/S3 は
  WEC のデータ形式そのものであり、可変にする要求は現れていない。
- Rust CLI / Flix 側（`cli/motorsport/src/mini_sector.rs`、
  `flix/src/Motorsport/MiniSector.flix`）の型。ワイヤ形式が変わらない限り
  Elm 側の整理とは独立している。提案 4 のデコーダ統合もワイヤ形式には触れない。
