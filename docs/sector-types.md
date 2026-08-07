# Sector / MiniSector の型の整理

`Motorsport` 配下で Sector と MiniSector のデータを持つ型を整理した記録。

各モジュールの型が「今どうなっているか」はドキュストリングにある。ここに残すのは
**なぜそうしたか**と、**差分を見ても分からないこと**だけ。

## 何が問題だったか

| 課題 | したこと |
| --- | --- |
| 区間の進行状況が `Float` に潰れ、読み手 3 か所が `progress < 1` で 3 状態を復元していた | `Performance.SegmentState` |
| `ByMiniSector` の API が `BySector` と揃っておらず、順序が `withDefault 0` 付きの線形探索 | `LeMans.all` / `toList` / `toString`、`toIndex` を `case` 式に |
| ミニセクターの区間切り出しが呼び出しのたびに再構築され、先頭が `SCL2 -> Just 0` の特別扱い | `Lap.miniSegments` |
| `Lap` とデコーダが同形のミニセクター型を二重定義。命名も `SectorTime` と非対称 | `MiniSectorTime` に統一（`personalBest` / `elapsedInLap`） |
| サーキットが `Race` に無く、描画側がイベント名の文字列一致でレイアウトを引いていた | `Race.circuit` と `Data.Series.Wec.circuit` |
| ミニセクターの有無が「空リスト 3 つ」で符号化され、Tracker の比率が毎フレーム線形探索 | `Circuit.Segmentation`、`TrackConfig` を位置引きに |
| 比率のハードコード表が、算出ロジックと二重の真実になっていた | 削除。算出できなければ均等割り |

見送ったものは「残っているもの」に。

## 差分から読み取れないこと

### `SegmentState` は整理ではなく保証の追加だった

旧実装は**未通過セクターにも `rated` を詰めていた**。リプレイデータなのでラップ全体の
セクタータイムは最初から存在し、まだ出していないタイムがビューから読める状態だった
（読み手が使っていなかっただけ）。`NotEntered` / `InProgress` に payload を持たせない
ことで、これがコンパイラの保証になる。`SnapshotTest` に回帰テストがある。

進行度は `min 1` にクランプされるため **`progress == 1` が実在する**（ラップ終端を
過ぎた時計）。旧 `progress < 1` はこれを「通過済み」に落としていたので、素直に
`EQ -> InProgress` と書くと配色が変わる。境界は `Performance.fromProgress` に閉じ込めた。

### `miniSegments` の切り出しで、原点の食い違いが見つかった

`currentMiniSector` は `lapStart current`（ラップ自身の終端 − 所要時間）を原点に
ミニセクターを選び、`miniSectorProgressAt` は `previous.elapsed`（前ラップの終端）を
原点に進行度を測っていた。両者が一致するのは隣接する完全なラップだけで、ずれた分は
`max 0 |> min 1` のクランプが吸収していた。長さの取り方も、選択は「累積の差」・
分母はソースの `.time` と食い違っていた。

`Segment` に一本化した結果、`miniSectorProgressAt` から `previous` 引数が消え
（`Race/Snapshot.readCurrentLap` の `previousLap` も）、`contains` が半開区間を保証
するのでクランプ自体が不要になった。

### `LeMans.initialize` はデコーダには使えない

`(mini -> a) -> ByMiniSector a` なので、`a` が `Decoder x` のとき得られるのは
`ByMiniSector (Decoder x)` であって `Decoder (ByMiniSector x)` ではない。15 個を畳む
方法はどれも「起こらないはずの既定値」を持ち込むため、レコード型エイリアスの構築子を
そのまま使う形にした。15 行の `|> required` は残る（ワイヤ形式が実際に 15 キー）が、
型が 1 つになったのでフィールド追加でデコーダのコンパイルが止まる。位置対応の
取り違えは `TimelineEventTest` が検出する。

### サーキットの配置先は「比率をリプレイ前に確定したい」で決まった

比率が依存するのはレイアウトと最終ベストタイムだけで、どちらも時計に依存しない。
後者が `Race` にある以上、前者も `Race` に置けば **比率は `Race` だけから決まる** —
`Tracker.trackOf : Race -> Track` になり、ロード時に 1 回で済む。

`EventSummary` に置いて別々に渡す案は、**組み合わせを取り違える窓がある**ため採らな
かった。`Shared.update` の `FetchJson_Wec` は `eventSummary` を即座に差し替える一方、
`replay` は fetch 完了まで前のレースのままなので、その間「新しいサーキット × 古い
レース」の組が作れる。`Race` に載せればこの窓は構造的に消える。

### 比率の既定値を均等割りにすると、ル・マンの見た目が変わる

旧既定値は重み付きで S1 0.18 / S2 0.367 / S3 0.453、均等割りでは
S1 0.2 / S2 0.267 / S3 0.533。これは「データ到着前の一瞬」の話ではない — 下記のとおり
**本番データにはミニセクタータイムが 1 つも届いていない**ため、ル・マンのトラックは
常に既定比率で描かれている。VRT スナップショットの更新が必要。

## 残っているもの

### ミニセクターのデータがローダーで捨てられている（最優先）

CLI は `_laps.json` の各ラップに `miniSectors` を書き出している
（`cli/cli/src/stages/output.rs`）が、`app/src/Data/Wec/Laps.elm` の `rawLapDecoder` は
このキーを読まず、`accumulate` が `miniSectors = Nothing` を直書きしている。結果、
アプリ上ではミニセクター関連（Leaderboard の 15 カラムストリップ、
`BestTimes.fastestMiniSectors`、Tracker のミニセクター粒度の位置、走行順のミニセクター
判定）がすべて動いていない。

`TimelineEvent.lapDecoder` は読むが、`TimelineEvent.decoder` はアプリから呼ばれておらず、
キーの綴りも CLI の現行出力と一致しない。

作業自体は素直で、`RawLap` に `miniSectors` を足し、CLI が書かない `personalBest` は
`accumulate` が `s1/s2/s3` に対してすでにやっている積算を `LeMans.map2` で流用すればよい。
入れると `totalTime` が 0 でなくなるため、トラック形状が実測比率に変わり VRT の更新が要る。

### `LeMans2025MiniSector` のドメイン層への焼き付け

`Lap` / `BestTimes` / `Performance` / `Race.Snapshot` が具体型を直接 import している。
総称化するには `initialize` / `get` / `map2` の 3 関数を引き回すレコードを全モジュールに
通すことになり（Elm に型クラス相当が無いため）、読みやすさを大きく損なう。`Dict` 化は
`ByMiniSector` を透過レコードにしている理由を捨てることになる。

ル・マン以外にミニセクターを持つデータが実際に入る時点で再検討する。それまでは
`all` / `toList` を揃えてあることで移行面積は小さい。

### 既知の癖

`Config.calcSectorBoundaries` は最終区間の終端（≒1.0）を `< 1` で落とすが、浮動小数の
積算で 0.9999… になると落ちず、コントロールライン上に境界線が 1 本描かれる。旧実装から
同じ挙動なので今回は変えていない。

### 触っていないもの

- `BySector` / `ByMiniSector` の不透明化 — `Sector.elm` に「守るべき不変条件が無く、
  同型 3 引数の構築子より名前付きフィールドのほうが安全」という判断が書かれており、
  覆す材料は見つからなかった
- `Sector` の構築子数 — S1/S2/S3 は WEC のデータ形式そのもの
- `Circuit.Circuit`（`{ name, layout }`）— どこからも使われていない未使用の型
- Rust CLI / Flix 側の型 — ワイヤ形式が変わらない限り独立
