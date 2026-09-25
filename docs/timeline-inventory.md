# タイムラインの棚卸し — `_timeline.jsonl` は観戦に足りているか

`Round.Timeline` が `laps` から数え上げて `*_timeline.jsonl` に書き、
`Page/Wec/Event.elm` のタイムラインパネルがその最新100件を新しい順に並べて見せている。
その中身を実測で洗い出し、「レースの展開が把握できるか」で判定した記録。

- 対象: `app/static/wec/2025/le_mans_24h_timeline.jsonl`(191行 / 12,737バイト)
- 日付: 2026-09-25(`d406766`)
- 数値の再測方法は末尾の付録に。`.#cli-load` → `.#cli-export` でファイルは再生成される。
- 適用済み: §5-4 の `start` を削除(191 → 129行)、§5-3 のとおり首位交代を2種に分割
  (`tookLead` 66 → `tookLeadOnTrack` 5 + `leaderPitted` 61)。後者は交代のイベントではなく
  「首位がピットインした」イベントで、首位だった車の in-lap の横断に生える。
  下の節は削除・分割前の実測。

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
「時刻 / カーバッジ / 英語ラベル文字列」の3列**で並べる。

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
- **ピット。** `Motorsport.Timeline` のコメント通り意図的除外だが、車ごとの詳細パネルにしかなく、
  「いまピットした組」をフィールド全体で読む場所が無い。caution 直後のピットラップは
  それ自体が展開。
- **ベストタイム更新。** summary の `index.bestTimeChanges` には出ていて timeline には無い。
  同じ時系列情報が2ファイルに分かれている。
- **ドライバー交代。** laps は `driverNumber` / driver name を持つ(車ごと表示のみ)。

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
   filter が `held IS NOT NULL`(`flix/src/Round/Timeline.flix:81`)でその行を落とす。
   実測: lap 1 の首位 #5(3:43.009)は行が無く、ファイル最初の tookLead は #4 の 45:55。
   #5 が開幕から3時間以上リードした区間がパネルに出ない。
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
3. **首位交代を2種に割る** — 先頭がピットに来ての交代と、コース上で抜き合った交代。
   `laps` は1回のストップを2つの横断に書いて持つ(ピットレーンに切れ込んだ横断と、
   ピットタイム付きの復帰横断)ので、「首位を失った車がこの周回をどちらかで横切ったか」
   で判別できる。SC明けかどうかの区別はしない —— 目的は交代の2種を分けること。
   **適用した形**: 判別は交代周回とその前周の両方にまたがる(ストップの2横断が1周離れて
   書かれるため)。当たりつきのイベントは交代としてではなく **`leaderPitted`** ——首位が
   ピットインした——として、首位だった車の in-lap の横断時刻に生やす。誰が首位に立ったかは
   表現しない。
4. **`start` を削るか `raceStart` に寄せる**(62行・32%が情報ゼロ)。 **適用済み**: 削った。

いずれも `Round.Timeline`(集計)+ `Motorsport.Timeline`(語彙と JSON 形)+
`package/src/Motorsport/Race/TimelineEvent.elm`(デコーダ)を同時に触る変更で、Elm 側は未知の
event 名で**ラウンド読み込みごと失敗する**仕様(`carEventTypeDecoder` が fail)、かつ行は
`timeline_events` に載るので反映は `.#cli-load` → `.#cli-export` が必要。

## 付録 — 数値の再測方法

```sh
# イベント種別の行数とフィールド
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
# と、tookLead の直前3分にピットした台数
python3 -c "
import csv,json,statistics,collections
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
tl=[json.loads(l) for l in open('app/static/wec/2025/le_mans_24h_timeline.jsonl') if 'tookLead' in l]
n=[sum(1 for u in pit if sec(e['elapsed'])-180<u<=sec(e['elapsed'])) for e in tl]
print('pits in the 3 min before a lead change: median',statistics.median(n),'>=4:',sum(1 for k in n if k>=4),'of',len(n))"

# 首位交代がコース上か、先頭がピットに来たためのものか(読み込み済みの行から)
# 2種に割る判別と同じ式:首位を失った車が in-lap か out-lap をこの周回か前周に横切ったか
sqlite3 flix/.db/motorsport.sqlite "
WITH l AS (SELECT car_number, lap_number, elapsed_ms,
   (crossing_finish_line_in_pit = 1 OR pit_time_ms IS NOT NULL) AS pitted,
   ROW_NUMBER() OVER (PARTITION BY lap_number ORDER BY elapsed_ms, source_row) AS rn
   FROM laps WHERE round_id =
     (SELECT round_id FROM rounds WHERE season = 2025 AND round_key = 'le_mans_24h'))
SELECT sum(came_in IS NOT NULL) AS leader_pitted,
       sum(came_in IS NULL) AS took_lead_on_track, count(*) AS changes
FROM (SELECT (SELECT l.elapsed_ms FROM l
               WHERE l.car_number = led.held
                 AND l.lap_number BETWEEN led.lap_number - 1 AND led.lap_number
                 AND l.pitted
               ORDER BY l.lap_number ASC LIMIT 1) AS came_in
      FROM (SELECT car_number, lap_number, elapsed_ms,
                   LAG(car_number) OVER (ORDER BY lap_number) AS held
            FROM l WHERE rn = 1) AS led
      WHERE held IS NOT NULL AND held <> car_number);"
```
