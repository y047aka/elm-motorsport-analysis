# データベース設計メモ

改修のための一時的な文書。**全工程の完了後に削除する。**

CLAUDE.md と flix/README.md は英語だが、この文書は改修中の作業用メモなので日本語で書く。
恒久的に残す内容は、改修が終わった時点でそれぞれの README に英語で移す。

計測はすべて実データに対して行った。CSV 14 ラウンド分（130,017 ラップ）を読み込み、
現行スキーマと候補スキーマを Python の `sqlite3` で再構築して測っている。DDL は
`Db.Laps` / `Db.Cars` の宣言から手で再現したもので、実際の `.#cli-load` が作る DB とは
ページサイズ等で数 % ずれる可能性がある。

---

## 結論

**エンジンは SQLite のままで正しい。設計の余地は SQLite の中にある。**
NoSQL / NewSQL に移す理由はこのワークロードには一つもない（第 4 節）。

一方で、正規化は途中で止まっている。`laps` から `cars` を切り出したのは第 2 正規形への
分解として完全に正しい判断だったが、同じ論理で残っている違反があと 2 つある。それを
片付けると、DB は 23.2MB → 約 11.8MB（約半分）になる。

さらに、一番効くのは DB ではなく JSON インターフェースの方である。ル・マンのラップ
ファイル 24.7MB のうち **49.4% が JSON のキー文字列**で、Elm が一度も読まない
フィールドが 26% を占めている。ただしこれは独立した最終工程として扱う（第 6 節）。

---

## 1. 現状を関数従属で読む

`laps` の主キーは `(season, round, car_number, lap_number)`。ここに存在する関数従属：

| 従属 | 状態 | 正規形上の位置づけ |
|---|---|---|
| `(season, round, car_number) → class, group, team, manufacturer` | **解決済み**（`cars` に分離） | 主キーの一部への部分関数従属 = 2NF 違反 |
| `(season, round, car_number, driver_number) → driver_name` | **未解決** | `driver_number` は非キー属性 → 推移的関数従属 = **3NF 違反** |
| `(season, round) → date, name` | **DB に存在しない**（Flix のコード内） | ラウンド実体そのものが不在 |
| `manufacturer → color, logo` | **DB に存在しない**（手書き JSON） | 参照実体が不在 |

`cars` を切り出したときの「アーカイブ全体で `(season, round, car_number)` が 2 通りに
記述されたものは無い」という検証と、まったく同じ検証を driver に対して行った：

```
driver slots (season,round,car,driver_number の組):  1,674
  そのうち driver_name が2通りあるもの:                  0
1ラウンドで2台に乗ったドライバー:                        0
driver_number の値域:                              1, 2, 3 のみ
```

違反ゼロ。つまり `entry_drivers(entry_id, driver_number) → driver_id` という分解は、
`cars` の分離とまったく同じ根拠で成立する。しかも `laps` は `driver_number` を
**すでに持っている**ので、必要なのは「`driver_name` 列を消す」ことだけで、新しい列は
1 つも増えない。

効果は大きい。現在 `driver_name` は 130,017 行に文字列として繰り返されているが、実体は
308 人・1,674 スロットである。加えて Elm 側では `Driver.fromName` による姓名分割が
**ラップごとに**走る（`app/src/Data/Wec/Laps.elm` の `accumulate`）。ル・マンなら 1 回の
ページロードで 20,182 回。実体は 186 人なので、99% が無駄な再パースになっている。

---

## 2. 提案スキーマ

### Tier 1 — モデルを変えない、ほぼ無料の改善

**(a) `WITHOUT ROWID` を両テーブルに。** これが単体で最大の効果。

現在 `laps` は暗黙の rowid でヒープに並び、そこに
`(season, round, car_number, lap_number)` の PK インデックスが完全に別ツリーとして
乗っている。両テーブルとも rowid でアクセスする箇所は一つもない（`Db.Laps.rows` は必ず
ラウンドでスコープされ、`Sql` は rowid を知らない）ので、これは純粋な二重持ちである。

**(b) 誰も読まない列を落とす。** `lap_improvement` / `s1..s3_improvement` /
`flag_at_fl` / `kph` / `top_speed` は、Flix 側では CSV デコード → `LapRow` →
`Db.Laps` → `Wec.toJson` の**素通し経路にしか出てこない**。`Cli.Load.Validation` も
`Round.Summary` も `Round.Index` も読まず、Elm 側は `app/src` `package/src` を通して
参照ゼロ。

ここは判断が要る。`source_row` が「`laps` は CSV の集合ではなく像である」と宣言して
いる以上、「読まれなくても file の忠実な像として持つ」は筋の通った選択である。ただし
その場合、**`laps` はアーカイブであってアプリの作業集合ではない**と決めたことになるので、
JSON へ素通しするのはやめるべきである。推奨は「DB には残す・JSON には出さない」。

**決定（A-3、実施済み）: 全列を残す。** `source_row` が置いている「`laps` は CSV の像
である」という約束の代金が、この 1.8MB である。落とすのは JSON の側だけで、それは
Phase C。

**(c) `kph` / `top_speed` を残すなら INTEGER（×10）に。** 現在 TEXT。

**決定（A-3、実施済み）: TEXT のまま。** アーカイブ 130,017 行を検めると `kph` は全件、
`top_speed` は 129,183 件が `d.d`（小数第一位まで）で、残る 834 件は空文字。つまり
INTEGER ×10 の往復は今日のデータでは安全に書ける。それでもやらないのは、往復を書いた
時点で「小数第一位で出す」という整形規則が export 側に生まれ、フィードが一度でも
小数第二位を書いた日に JSONL が黙って変わるからである。得るのは 0.8MB で、`Db.LapRow`
が置いている「デコーダがパースしなかったものをロードもパースしない」という線を引き
換えにする値ではない。

### Tier 2 — 同一性の層（本体の設計）

```sql
-- ラウンド実体。Motorsport.Calendar.entries() から load 時に seed する
CREATE TABLE rounds(
  round_id   INTEGER PRIMARY KEY,
  season     INT  NOT NULL,
  round_key  TEXT NOT NULL,
  date       TEXT NOT NULL,
  loaded_at  TEXT,                     -- 両テーブルの投入成功後に、同一 tx 内で立てる
  UNIQUE(season, round_key));

CREATE TABLE manufacturers(
  manufacturer_id INTEGER PRIMARY KEY,
  name            TEXT NOT NULL UNIQUE,
  canonical_id    INT REFERENCES manufacturers);  -- Mercedes-AMG → Mercedes

CREATE TABLE teams  (team_id   INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE);
CREATE TABLE drivers(driver_id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE);

-- 旧 cars。「1ラウンドの1台」であることは変えない
CREATE TABLE entries(
  entry_id        INTEGER PRIMARY KEY,
  round_id        INT  NOT NULL REFERENCES rounds,
  car_number      TEXT NOT NULL,
  class           TEXT NOT NULL,
  car_group       TEXT NOT NULL,
  team_id         INT  NOT NULL REFERENCES teams,
  manufacturer_id INT  NOT NULL REFERENCES manufacturers,
  UNIQUE(round_id, car_number));

CREATE TABLE entry_drivers(
  entry_id      INT NOT NULL REFERENCES entries,
  driver_number INT NOT NULL,
  driver_id     INT NOT NULL REFERENCES drivers,
  PRIMARY KEY(entry_id, driver_number)) WITHOUT ROWID;

CREATE TABLE laps(
  entry_id INT NOT NULL REFERENCES entries,
  lap_number INT NOT NULL, source_row INT NOT NULL, driver_number INT NOT NULL,
  ... ,                                  -- driver_name は無い
  mini_sector_time_ms TEXT, mini_sector_elapsed_ms TEXT,
  PRIMARY KEY(entry_id, lap_number),
  UNIQUE(entry_id, source_row)) WITHOUT ROWID;
```

### 実測（アーカイブ全体・14 ラウンド・130,017 ラップ）

| 段階 | サイズ | 差分 |
|---|---:|---:|
| 現行（再現） | 23.17 MB | — |
| + `WITHOUT ROWID` | 19.48 MB | −3.69 |
| + `round_id` 代理キー（`season`+`round` テキスト置換） | 16.23 MB | −3.25 |
| + `driver_name` を `entry_drivers` へ | 13.51 MB | −2.72 |
| + `kph`/`top_speed` を数値化 | ≈ 13.5 MB | −0.26 |
| + 未読列を落とす | **≈ 11.8 MB** | −1.76 |

**読み取り性能は落ちない。**むしろ改善する：

| クエリ（ル・マン 2025・20,182 ラップ） | 現行 | 正規化後 |
|---|---:|---:|
| ラウンド全読み（`Round.Laps.read`） | 80.4 ms | 96.3 ms |
| `lapCompletions`（GROUP BY） | 8.6 ms | 6.8 ms |
| ミニセクター最速（`json_each`） | 118.4 ms | 114.1 ms |
| グリッド順（`carBuilds` 相当の JOIN） | 14.6 ms | **5.1 ms** |
| ファステスト推移（ウィンドウ関数） | 61.8 ms | 53.1 ms |

全読みだけ 20% 遅い（+16ms）のは JOIN のせいだが、**これは実際には発生しない**。
`Round.Laps.read` は SQL で JOIN せず、`Round.Cars.read` が車を `Map` に一度読んで
Flix 側で引いている。キーを `car_number` から `entry_id` に変えるだけで、JOIN なしの
まま同じ構造が保てる。

### この分解が「ついでに」解決すること

サイズより重要。**現在のスキーマでは答えられない問いが答えられるようになる。**

- **ドライバーの同一性。** 308 人中 227 人が複数ラウンドに登場するが、いま横断で引く
  手段は名前の文字列マッチしかない。`drivers` があれば「小林可夢偉の 2024–2026 全
  ラップ」が 1 クエリになる。
- **`Round.loaded` が推測でなく事実になる。** いまは両テーブルを `LIMIT 1` で叩いて
  「laps はあるが cars が無い = 半分ロード」を検出している。`rounds.loaded_at` を
  **両方の投入が成功した後・同一トランザクション内で**立てれば、半端な状態が原理的に
  存在しなくなる。プローブが不変条件に変わる。
- **`Db.Error.Incomplete` が読み取り時から書き込み時に移る。** 「laps はあるが `cars`
  に行が無い車」はいま `Round.Laps.rawLap` が読み出し時に検出している。FK 宣言 +
  `PRAGMA foreign_keys=ON` にすれば、これは INSERT が拒否する制約違反になる。
  **エラーが直せる場所で出る**ようになるのが本質。
- **`Db.Schema.scopeOf` の存在理由が半分消える。** あれは「両テーブルが
  `season`/`round` を持つので、JOIN でスコープが誤った側に束縛される」ことへの防御
  だった。単一の `entry_id` FK なら、そもそも両側が同じ列名を持つ状況が起きない。
- **`manufacturers.json` の危険が型に乗る。** CLAUDE.md が「コンパイラが読まないので、
  間違いはビルド失敗ではなく『車が番号で描かれる』という形で現れる」と警告している
  箇所。`manufacturers` テーブル + FK にすれば load が検証する。そして `canonical_id`
  が `Mercedes` / `Mercedes-AMG` 問題（flix/README.md に記録されている、同一シーズン内
  で同じメーカーが 2 色で描かれる件）の置き場になる。

  ただし**色とロゴをどこに置くかは別の判断**である。CLAUDE.md は「どのメーカーがいて、
  どう色付けバッジ付けするかは、1 シリーズのエントリーリストとこのアプリのアセット
  である」として意図的にアプリ側に置いている。推奨は割る形：**エイリアス→正規名の
  対応は DB へ**（これはフィードについての事実）、**色とロゴは今の場所のまま**（これは
  アプリの表現）。両方入れるなら「DB はアプリのアセットレジストリでもある」と明示的に
  決めた上で。その場合の副次的な利益として、色がラウンドサマリーに同梱でき、
  `manufacturers.json` への 2 本目のフェッチ（いまラウンド表示のクリティカルパスに
  乗っている）が消える。

### 変えるべきでないもの

- **ミニセクターの JSON 配列は維持。** 正規化した版（`lap_mini_sectors` に 300,487 行）
  も測ったが、13.19MB → 14.54MB と**大きくなる**上、`json_each` が既に行の形を与えて
  いるので得るものがない。トラック順が添字で表現されるのも配列の方が素直。この判断は
  正しいので変えない。
  - 一つだけ将来の注記：添字が場所を意味する規約は「15 個・`Motorsport.MiniSector.all()`」
    に固定されている。別サーキットが違う個数のミニセクターを持った瞬間に壊れる。値を
    正規化せずに**意味だけ**を守るなら `circuit_mini_sectors(circuit_id, position, code)`
    を持つ形になる。
- **`cars` をシーズン単位でなくラウンド単位で持つこと。** flix/README.md の理由（同一
  シーズン内でのメーカー表記揺れ）がそのまま正しい。
- **`source_row`。** 荷重を持っている列（バリデーションの基準行、ドライバーの登場順、
  グリッド順）。
- **追加インデックス。** `GROUP BY lap_number` と `ORDER BY elapsed_ms` は現状
  インデックス無しで 8.6ms。1 ラウンド 2 万行に対してインデックスを足す価値はない。

---

## 3. インターフェース（JSON）

DB より効く。ル・マン 2025 のラップファイル 24.7MB の内訳：

```
JSON のキー文字列  12.21 MB (49.4%)
値                 7.47 MB (30.2%)
うち miniSectors   12.65 MB (51.1%)
Elm が一度も読まない項目（improvement×4 / kph / topSpeed / flagAtFl / hour /
crossingFinishLineInPit）
                   約 6.5 MB (26%)
```

さらに、`Duration` は Elm 側で `type alias Duration = Int`（ミリ秒）、`Instant` も内部は
ミリ秒である。**DB もミリ秒 INTEGER で持っている。**つまり `"3:54.555"` というテキストは、
ミリ秒 → テキスト → ミリ秒 と往復しているだけで、誰の役にも立っていない。

3 案を実測した：

| 案 | 生 | gzip |
|---|---:|---:|
| 現行 | 24.74 MB | 3.38 MB |
| 未読フィールドを落とすだけ | 18.22 MB | 2.96 MB |
| **オブジェクト維持・ms 整数・ミニセクターを配列 2 本・ドライバーをインデックス・未読削除** | **6.01 MB (24%)** | **2.17 MB (64%)** |
| 全部位置引数の配列にする | 5.16 MB (21%) | 2.09 MB |

**推奨は 3 案目。**完全な位置引数配列との差は 0.85MB しかなく、その代わり 1 行 1 ラップの
可読性（人間が `head` して確認できること）を保てる。しかもミニセクターを配列 2 本にする
形は、**DB がすでに持っている形そのもの**なので、`Wec.toJson` は変換をやめるだけになる。

生サイズが 4 分の 1 になることの意味は転送量ではない。クライアントのコストは
`JSON.parse` とデコーダのアロケーションが支配しており、それは gzip 後ではなく
**生バイト数**に比例する。実質的にデコード仕事量が 4 倍軽くなる。

**ただしこの変更は独立した最終工程として扱う。**理由と段階分けは第 6 節。

### もう 1 つ、JSON に載せるべきもの：`position`

`app/src/Data/Wec/Laps.elm` の `assignPositions` が一番重い箇所：

```elm
List.foldl assignPositionsForLap cars (List.range 1 maxLap)
```

`assignPositionsForLap` はラップ番号ごとに、**全車の全ラップを `List.map` で作り直す**。
ル・マンなら 387 × 20,182 = **約 780 万回のラップレコード再構築**。加えて
`List.Extra.find` が 387 × 62 × 平均 325 で更に約 780 万ステップ。これがページを開く
たびに走る。

SQL では 1 本のウィンドウ関数で **33.2ms**：

```sql
ROW_NUMBER() OVER (PARTITION BY lap_number ORDER BY elapsed_ms) - 1
```

ワイヤ上のコストはラップあたり整数 1 個（約 80KB、上の 6.01MB に対して 1.3%）。
flix/README.md の「SQL が得意なのは数えることであって、決めることではない」という
線引きにそのまま乗る移動である。`Round.Summary` がグリッド順を SQL に移したときと同じ
理屈で、これはまだ移っていない最後の一つ。

なお `personalBest`（ラップ・セクターの走行中ベスト）の方は Elm 側の畳み込みが既に
O(n) 線形なので、SQL に移す必要はない。移すとワイヤが太るだけで割に合わない。
**position だけが例外的に非線形**なのがポイント。

---

## 4. SQLite / NoSQL / NewSQL

ワークロードの言語化：

- **書き込み**：バッチ、全面再構築、単一ライター、130k 行、データ更新時のみ。
- **サーバ読み取り**：ラウンド全走査、`GROUP BY`、ウィンドウ関数、`json_each`。
  **点検索ゼロ、同時書き込みゼロ、ユーザ間トランザクションゼロ**。純粋な OLAP。
- **クライアント読み取り**：ラウンド丸ごとを 1 ファイルとして受け取る。**API は
  ユーザー操作ごとにクエリを受けない。**事前計算されたバイト列を返すだけ。

最も重要な性質：**この DB は system of record ではなく、CSV から導出されたキャッシュ
である。**毎回 `DROP TABLE` して作り直す設計がそれを宣言している。だからこそ耐久性・
レプリケーション・マイグレーション・可用性の議論が丸ごと適用されない。

| 候補 | 判定 |
|---|---|
| **SQLite（現行）** | **正しい。**単一ファイル、単一ライター、埋め込み、WAL で読み書き並走、`json_each` と完全なウィンドウ関数。要件と完全に一致。 |
| **DuckDB** | 技術的には最も近い対抗馬。列指向でウィンドウ関数が速く、`LIST`/`STRUCT` 型がミニセクターを JSON テキストでなくネイティブに持てる。JDBC ドライバもある。**しかし決定的な障害が 1 つ**：DuckDB のファイルはプロセス単位でロックされ、SQLite の WAL のような「読み手が書き手の横で読む」形が作れない。`.#serve-api` を上げたまま `.#cli-run` を回す現在の運用が壊れる。130k 行では速度差も回収できない。**不採用。** |
| **NoSQL（ドキュメント指向）** | 読み取り経路には合うが、**すでにそうなっている**。「ラウンド 1 つ = ドキュメント 1 つ」を静的ファイルで実現しているのが `.json` + `.jsonl` + `index.json` で、これはドキュメントストアとして最も安いもの。そしてインデックスを計算するウィンドウ関数と `GROUP BY` が失われるので、書き込み側が成立しない。**不採用。**（起きていることを正確に言えば、この構成は既に「クエリは RDB、配信はドキュメント」のハイブリッドである。） |
| **NewSQL（CockroachDB / TiDB / Spanner）** | 解く問題は「分散書き込みの一貫性」と「水平スケール」。ここは単一ライター・23MB・単一リージョン・導出データ。**得るものがゼロで運用コストだけが乗る。不採用。** |
| **時系列 / 列指向 DWH（ClickHouse 等）** | クエリ形状は本当に合っている（ラップは時間軸を持つイベント）。ただし 130k 行は ClickHouse が有利になる領域より**5 桁下**。 |

**スケール見積り**：WEC 全史（20 シーズン × 8 ラウンド ≈ 160 ラウンド）でも約 150 万
ラップ、正規化後で 150MB 程度。IMSA や F1 を足しても数 GB。SQLite の快適域を出ない。
**「いつか乗り換える」ための備えも不要**と考えて良い規模である。

---

## 5. Flix 側の型に効く小さな副産物

正規化とは別に、`Sql` の raw ホールを 1 つ減らせる。`Db.Laps.hourOffset()` は

```flix
"((hour_ms - elapsed_ms) % 86400000 + 86400000) % 86400000"
```

という文字列で、`Round.Summary.startedAt` と `Cli.Load.Validation` が使っている。
SQLite の生成列にすれば：

```sql
hour_offset_ms INT GENERATED ALWAYS AS
  (((hour_ms - elapsed_ms) % 86400000 + 86400000) % 86400000) VIRTUAL
```

`Db.Schema.integer("hour_offset_ms", ...)` として**型のついた列**になり、`Sql.raw` を
通らずに `Sql.eq` で比較できる。VIRTUAL なのでストレージも 0。flix/README.md が sqlfx
との比較で「`RawSql` エフェクトが無いので、チェックされない SQL がどこまで届いているか
は grep でしか分からない」と書いている、その面積を実際に減らす変更である。

---

## 6. 改修の段階分けと PR 粒度

### ワイヤ形式の変更を最終工程に切り離す

第 3 節の JSONL 再エンコードは、効果としては単体で最大だが、**改修中は現行の形式を
維持する。**理由：現在の JSONL は CSV とフィールドがある程度対応しており、改修の各段階で
CSV と JSONL を目視で突合して検証できる。この利点を、DB 側の構造を動かしている最中に
手放したくない。したがって JSONL の再エンコードは、DB 側がすべて落ち着いた後の
**独立した最終工程**とする。

この方針の帰結として、第 2 節・第 3 節で 1 つの項目として書いた変更のうち、**ワイヤに
触れる半分は Phase C に分かれる**：

- **ドライバーの正規化**（第 1 節）— DB 側（`drivers` + `entry_drivers`、`laps.driver_name`
  削除）は Phase B。JSONL の `driverName` をインデックスに置き換えるのは Phase C。
  Phase B の間、export は `entry_drivers` を引いて `driverName` を今までどおり書き出す。
  これがワイヤを据え置くための繋ぎになる。
- **未読列**（Tier 1 (b)）— 「DB に残す / 落とす」の判断は Phase A。JSON から外すのは
  Phase C。
- **`position`**（第 3 節）— これは JSONL への**追加**であって既存フィールドの
  再エンコードではないので、CSV との突合を妨げない。Phase A に置く。

### PR 分割

依存関係は表の順に走る。

**Phase A — モデルを変えない**

| PR | 内容 | 効果 |
|---|---|---|
| A-1 | `WITHOUT ROWID` を `laps` / `cars` に | −3.7MB (16%)。`Sql.createTable` に 1 語 |
| A-2 | `position` を SQL の `ROW_NUMBER` で出し、`assignPositions` を削除 | Elm から 780 万回の再構築が消える（SQL 33ms）。JSONL に加算的な 1 フィールド |
| A-3 | 未読列の扱いを決める（DB に残す / 落とす）。落とすなら `kph`/`top_speed` の数値化も | 落とす場合 −1.8MB。判断が主 |

**Phase B — 同一性の層**

| PR | 内容 | 効果 |
|---|---|---|
| B-1 | `rounds` テーブル + `round_id` FK + `loaded_at`、`cars` → `entries`、`laps` を `entry_id` キーに | −3.25MB。`Round.loaded` が不変条件になる。`Db.Schema.scopeOf` 周辺の書き換えを伴う |
| B-2 | `drivers` + `entry_drivers`、`laps.driver_name` 削除（export は join して従来どおり書き出す） | −2.7MB。ドライバー横断クエリが可能になる |
| B-3 | `manufacturers` + `canonical_id`、`teams`。色・ロゴの置き場を先に決める | Mercedes/Mercedes-AMG 解決、FK で `manufacturers.json` を検証 |
| B-4 | `hour_offset_ms` を生成列に | raw SQL が 1 つ減る |

**Phase C — 独立した最終工程（ワイヤ形式）**

| PR | 内容 | 効果 |
|---|---|---|
| C-1 | JSONL を ms 整数 + ミニセクター配列 2 本 + 未読フィールド削除 + ドライバーのインデックス化 | 生 24.7 → 6.0MB、デコード仕事量 4 分の 1 |

**Phase D**

| PR | 内容 |
|---|---|
| D-1 | この文書を削除し、恒久的に残す内容を CLAUDE.md / flix/README.md へ英語で移す |

Phase A の 3 本はモデルを一切変えずに効くので先に片付ける価値がある。設計の練習という
観点では **Phase B が本体**で、`cars` を切り出したのとまったく同じ推論（関数従属を
見つけて、アーカイブ全体でそれが破れていないか実データで確認して、分解する）を、
driver と round に対してもう一度適用する作業になる。データ側の検証は第 1 節で済ませて
あり、違反ゼロである。
