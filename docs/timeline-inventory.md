# タイムラインの棚卸し — `_timeline.jsonl` は観戦に足りているか

`Round.Timeline` が `laps` から数え上げて `*_timeline.jsonl` に書き、
`Page/Wec/Event.elm` のタイムラインパネルがその最新100件を新しい順に並べて見せている。
その中身を実測で洗い出し、「レースの展開が把握できるか」で判定した記録。

- 対象: `app/static/wec/2025/le_mans_24h_timeline.jsonl`(191行 / 12,737バイト)
- 日付: 2026-09-25(`d406766`)
- 数値の再測方法は末尾の付録に。`.#cli-load` → `.#cli-export` でファイルは再生成される。
- 適用済み: §5-4 の `start` を削除(191 → 129行)、§5-3 のとおり首位交代を2種に分割
  (`tookLead` 66 → `overtakeForLead` 5 + `leaderInPit` 68、136行)。後者は交代のイベントでは
  なく「首位がピットインした」イベントで、首位だった車の in-lap の横断に生える。
  交代から数えた初版では首位のままピットアウトした7件が漏れていた(→§5-3)。
  あわせて `retirement` → `retired`、`checkered` → `finished` と、表示名
  (Race Start / Overtake for Lead / Leader In Pit / Retired / Finished)に名前をそろえた。
  §5-2 のとおり首位をクラスごとに数えるようにした(`overtakeForLead` 10 + `leaderInPit` 175、
  248行)。§3 のドライバー交代を全車分 `driverChange` として足した(+611、859行)。
  §3 のベストタイム更新はクラスごとのファステストラップを `fastestLap` として足した(+30、889行)。
  下の節は削除・分割・改名・クラス別化の前の実測で、旧名のまま書いてある。

## 1. 出力されているもの

行の形は3フィールドのみ。lap番号・クラス・順位・ギャップ・フラグ状態は一切ない。
`raceStart` だけが `carNumber` を持たない(`flix/src/Motorsport/Timeline.flix:parts`)。

| event | 行数 | 出所(`flix/src/Round/Timeline.flix`) | 意味 |
| --- | ---: | --- | --- |
| `raceStart` | 1 | 常に elapsed=0 を置くだけ | レース開始 |
| `start` | 62 | `cars()` が laps に行を持つ各車を列挙、elapsed は**全車 0 固定**(`Motorsport.Timeline.starts`) | スタートした |
| `tookLead` | 66 | `leads()`: lap ごとの最初の通過者が前の lap から変わった瞬間 | 総合首位に立った |
| `retirement` | 13 | `terminals()`: 最終通過が timeLimit(24:00)より前 | リタイア |
| `checkered` | 49 | 同上、timeLimit 以降 | フィニッシュ |

## 2. 画面での表示

`app/src/Page/Wec/Event.elm` の `timelinePanel`(唯一の消費者。`Shared` が持つだけ)が、
再生時刻までの件数を `Timeline.countUpTo` で二分検索し、**直近100件を新しい順に
「カーバッジ / 英語ラベル文字列 / 時刻」の3列**で並べる(棚卸し時は「時刻 / カーバッジ /
英語ラベル」の順で、ラベルが右寄せだった)。

色分け・アイコン・分類・フィルタは無く、行そのものは読み取り専用で、
クリックは全順位ポップオーバーを開くボタンになっている。

## 3. 「観戦・展開の把握に役立つか」での判定

### 有用

- `retirement`(13) — 時刻が効く。ただし §4-2 の通り二重導出。
- `tookLead`(66) — laps から再生しにくい情報で行として正しい。ただし意味が曖昧(§4-3)。

### 弱い / 冗長

- **`start` 62行(全体の32%)は情報がゼロ。** スタート順と位置は summary の
  `startingGrid`(62 entries、`position` 付き)に出ていて、Leaderboard の順位変動列と
  CarDetail ヘッダーに表示済み。しかも elapsed=0 固定なので **t=0 でパネルの63行が
  "Start" の壁**になり、再生直後のいちばん見たい時間帯を埋める。
- **`checkered` 49行はゴール通過順の羅列**で、「展開」ではない(末尾のレポートとしては機能する)。
- **首位経験はハイパーカー8台だけ**(実測 #4/#5/#6/#8/#50/#51/#83/#94、最多が #83 の24回)。
  ル・マンは3クラス同時進行で、総合首位の入れ替わりしか出ていない。

### 出ていないが `laps` に既にあり、効くもの

- **FCY / SF(caution)約12期間。** CSV の `FLAG_AT_FL`(非緑の通過528回 =
  SF 320 + FCY 159 + FF 49)は laps テーブルを経て `_laps.jsonl` の `flagAtFl`
  まで届いているのに、**Elm 側でそれを読む箇所がどこにもなく**画面のどこにも出ない。
  耐久で最大の展開要因なのに。
- **クラス別の首位交代。** 総合しか見ていないのでハイパーカー8台の話になり、
  LMP2 の35回・LMGT3 の37回のリーダー交代が丸ごと無い(`leads()` にクラスの軸を足すだけ)。
- **ピット。** `Motorsport.Timeline` のコメント通り意図的除外で、「いつ誰が入ったか」を
  時系列で読む場所が無い。caution 直後のピットラップはそれ自体が展開。
  (訂正: 「いまピット中の車」は棚卸し時点でも順位表の各行に「P」印で出ていた。無いのは時系列の方。
  首位車の分は `leaderInPit` で埋まった。)
- **ベストタイム更新。** summary の `index.bestTimeChanges` には出ていて timeline には無い。
  同じ時系列情報が2ファイルに分かれている。
  **適用済み**: ファステストラップだけを、首位と同じくクラスごとに `fastestLap` として出す
  (Le Mans 2025 で30回。セクターとミニセクターの記録は出さない)。2段目に周回タイムと
  ドライバーを添え、どちらもアプリがその車の周回から引く。1周目はタイムラインの集計から外した:
  1周目のタイムはレースの経過時間そのもので、Fuji 2024・2025、Spa 2025、Bahrain 2024 では
  トップの1周目がレース中のどの周より速い。`Round.Index` の記録(`bestTimeChanges`)は
  1周目を含めたままで、アプリの周回タイムの色付けはその記録に対して行われている(未対応)。
- **ドライバー交代。** laps は `driverNumber` / driver name を持つ(車ごと表示のみ)。
  **適用済み**: 全車の交代を `driverChange` として出す(Le Mans 2025 で611回、全ラウンドで
  交代はすべてピット明けの周回)。時刻は新ドライバーの最初の周の直前の通過で、アプリが
  `currentDriver` を切り替える瞬間と同じ。交代先の名前はファイルに持たせず、アプリがその車の
  周回から引く。パネルの100件は、180周目(最新 11:02:00)の時点で 8:17:20 まで遡る。

### caution が「展開」である決定的な根拠

リタイアと cautions が分単位で連なっている。タイムラインは前半しか言及していない。

| retirement | elapsed | 直後の caution |
| --- | --- | --- |
| #24 | 11:10:29 | SF 11:11:48(320通過にまたがる長いブロック) |
| #78 | 19:02:41 | FCY 19:03:48 |
| #59 | 22:52:42 | FCY 22:58:37 |

## 4. 棚卸し中に見つけた実装側の問題

1. **オープニングリーダーは出力されない(コメントと挙動が食い違う)。**
   `Round.Timeline.leads` の doc comment は
   「先頭ラップのリーダーは誰からも奪っていない = `LAG` が null」と読めるが、直後の
   filter が `held IS NOT NULL` でその行を落とす。
   実測: lap 1 の首位 #5(3:43.009)は行が無く、ファイル最初の tookLead は #4 の 45:55。
   #5 が開幕から3時間以上リードした区間がパネルに出ない。
   **未修正**: 同じ条件が今は `Round.Timeline.overtakes` の filter にある。#5 は 42:11 の
   `leaderInPit` で初めて現れるが、開幕から首位だったことはどこにも書かれない。
2. **`retirement` / `checkered` は二重導出。** `Race.statusAt`
   (`package/src/Motorsport/Race.elm`)が同じ laps + timeLimit で同じ判定を再生毎にやり直し、
   Standings が動かしているのはこちら。timeline 側は表示上レポート風の後乗りで、
   timeLimit を共有するので現状は一致している(食い違えば表示がねじれる)。
3. **`tookLead` のラベルが実態と合わない。** 66回の交代のうち**中央値で直前3分に5台が
   ピットイン**(4台以上が39/66)、つまり大半はスティント・ローテーションなのに "Took the Lead"。
   どこで交代したか(コース上かピットで来たのか)を示す欄が無い。
4. **`retirement` は「24:00より前に最終周回を切った」**なので、境界直前で走って切れた車は
   retirement に寄る。このレースでは最も遅い retirement が 22:52 で誤検出はなかった。

## 5. 変えるなら優先度

1. **caution エピソード(`slowZone` / `fullCourseYellow` の開始・終了)を追加** —
   表示上の最大の空白、+12行程度、`laps.flag_at_fl` から集計できる。
2. **`tookLead` にクラスを持たせる**(LMP2/LMGT3 の展開が出る。+72行程度)。
   **適用済み**: 首位をクラスごとに数え、総合首位は別に数えない。読み込んだ14ラウンドすべてで、
   ハイパーカーの首位と総合首位の行が一致したため。ファイルの形は変えず、クラスはアプリが
   車の情報から引き、パネルはカーバッジの左にクラス色の縦線を出す。
   見積もりの +72 行は交代を数えた場合で、実際は +112 行(LMP2 1 + 55、LMGT3 4 + 52)。
   下位クラスの首位交代はほとんどがピットの周期で起きるため、増えた行の大半は `leaderInPit`。
   パネルの100件は、180周目(最新 10:58:55)の時点で 36:56 まで遡る。
3. **首位交代を2種に割る** — 先頭がピットに来ての交代と、コース上で抜き合った交代。
   `laps` は1回のストップを2つの横断に書いて持つ(ピットレーンに切れ込んだ横断と、
   ピットタイム付きの復帰横断)ので判別できる。SC明けかどうかの区別はしない ——
   目的は2種を分けること。
   **適用した形**: 交代から割るのをやめ、**首位車のストップを交代と独立に数える**関数に
   分けた。交代（`overtakeForLead`）は前首位が stop 横断を持たない周回境界だけ、
   **`leaderInPit`** は out-lap（`pit_time` 付き。1ストップ1行なので数えの anchor にする）
   を中心に、その2周前までに首位だった車を、切れ込んだ in-lap の横断時刻に出す。
   交代を先に聞くと**首位のままピットアウトした7件**（うち6件は #51 が後半に引き離した
   後）がイベントにならない。首位交代そのものは表現しない。
4. **`start` を削るか `raceStart` に寄せる**(62行・32%が情報ゼロ)。 **適用済み**: 削った。

いずれも `Round.Timeline`(集計)+ `Motorsport.Timeline`(語彙と JSON 形)+
`package/src/Motorsport/Race/TimelineEvent.elm`(デコーダ)を同時に触る変更で、Elm 側は未知の
event 名で**ラウンド読み込みごと失敗する**仕様(`carEventTypeDecoder` が fail)、かつ行は
`timeline_events` に載るので反映は `.#cli-load` → `.#cli-export` が必要。

## 付録 — 数値の再測方法

```sh
# イベント種別の行数(今のファイル。棚卸し時点の数は `git show d406766:<path>` を読む)
python3 -c "import json,collections;rows=[json.loads(l) for l in open('app/static/wec/2025/le_mans_24h_timeline.jsonl')];print(collections.Counter(r['event'] for r in rows))"

# 首位経験と交代回数(総合 / クラス別)。先頭ラップのリーダーを含めた数
python3 -c "
import csv,collections
rd=csv.DictReader(open('app/static/wec/2025/le_mans_24h.csv',encoding='utf-8-sig'),delimiter=';')
ms=lambda s:[float(x) for x in s.split(':')]
sec=lambda s:(lambda p:3600*p[0]+60*p[1]+p[2])(([0]*(3-len(ms(s))))+ms(s))
rows=list(rd)
for cls in ['HYPERCAR','LMP2','LMGT3']:
    first={}
    for r in sorted([r for r in rows if r['CLASS']==cls],key=lambda r:(int(r[' LAP_NUMBER']),sec(r[' ELAPSED']))):
        first.setdefault(int(r[' LAP_NUMBER']),r['NUMBER'])
    laps=sorted(first);ch=[first[n] for i,n in enumerate(laps) if not i or first[n]!=first[laps[i-1]]]
    print(cls,len(laps),'laps',len(ch),'lead changes incl opener',dict(collections.Counter(ch)))"

# caution 期間(非緑の通過を4分以内の間隔で連結。FF はゴールなので期間に数えない)
# と、tookLead の直前3分にピットした台数。tookLead は今のファイルに無いので、
# 棚卸し時点(d406766)のファイルを読む
python3 -c "
import csv,json,statistics,collections,subprocess
rd=csv.DictReader(open('app/static/wec/2025/le_mans_24h.csv',encoding='utf-8-sig'),delimiter=';')
ms=lambda s:[float(x) for x in s.split(':')]
sec=lambda s:(lambda p:3600*p[0]+60*p[1]+p[2])(([0]*(3-len(ms(s))))+ms(s))
fmt=lambda t:'%d:%02d:%06.3f'%(t//3600,t%3600//60,t%60)
rows=list(rd)
ng=sorted((sec(r[' ELAPSED']),r['FLAG_AT_FL']) for r in rows if r['FLAG_AT_FL']!='GF')
eps=[]
for t,f in ng:
    if eps and eps[-1][2]==f and t-eps[-1][1]<300: eps[-1][1]=t
    else: eps.append([t,t,f])
print('non-green crossings',len(ng),collections.Counter(f for _,f in ng))
for a,b,f in eps:
    if f!='FF': print(f,fmt(a),'->',fmt(b))
pit=sorted(sec(r[' ELAPSED']) for r in rows if r['PIT_TIME'].strip())
old=subprocess.check_output(['git','show','d406766:app/static/wec/2025/le_mans_24h_timeline.jsonl'],text=True)
tl=[json.loads(l) for l in old.splitlines() if 'tookLead' in l]
n=[sum(1 for u in pit if sec(e['elapsed'])-180<u<=sec(e['elapsed'])) for e in tl]
print('pits in the 3 min before a lead change: median',statistics.median(n),'>=4:',sum(1 for k in n if k>=4),'of',len(n))"

# overtakeForLead と leaderInPit(`Round.Timeline` と同じ式)。交代から数えると 61 になり、
# 首位のままピットアウトした7件が落ちる
sqlite3 flix/.db/motorsport.sqlite "
WITH l AS (SELECT car_number, lap_number, elapsed_ms, source_row,
   (crossing_finish_line_in_pit = 1 OR pit_time_ms IS NOT NULL) AS pitted,
   (pit_time_ms IS NOT NULL) AS stopped,
   ROW_NUMBER() OVER (PARTITION BY lap_number ORDER BY elapsed_ms, source_row) AS rn
   FROM laps WHERE round_id =
     (SELECT round_id FROM rounds WHERE season = 2025 AND round_key = 'le_mans_24h')),
led AS (SELECT car_number, lap_number FROM l WHERE rn = 1)
SELECT (SELECT count(*) FROM (
          SELECT 1 FROM (SELECT car_number, lap_number, elapsed_ms,
                          LAG(car_number) OVER (ORDER BY lap_number) AS held
                         FROM l WHERE rn = 1) AS chg
          WHERE held IS NOT NULL AND held <> car_number
            AND NOT EXISTS (SELECT 1 FROM l x WHERE x.car_number = chg.held
                   AND x.lap_number = chg.lap_number AND x.pitted))) AS overtake_for_lead,
       (SELECT count(*) FROM l AS stop WHERE stop.stopped
          AND EXISTS (SELECT 1 FROM led WHERE led.car_number = stop.car_number
                       AND led.lap_number IN (stop.lap_number - 2, stop.lap_number - 1))) AS leader_in_pit;"
```
