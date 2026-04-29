/// CSV → JSON 変換時に走る入力データ整合性チェック。
///
/// 検査ルールはすべて 0ms 厳密一致で、違反は警告として返すのみ
/// (exit code には影響しない)。Stages.processFile 側で stderr に出力される。
///
/// ルール:
///   1. SectorSum         — `s1 + s2 + s3 == lapTime` (per row)
///   2. ElapsedDrift      — 同一カーで `elapsed[n] == sum(lapTime[1..=n])`
///                          (累積和ベース: 最初に drift した行以降を全て報告)
///   3. HourElapsedOffset — CSV 全体で `(hour - elapsed) mod 24h` が一定
///   4. HourUnparseable   — hour 列がパース不能(空欄・H:MM:SS 形式以外)
///
/// 設計メモ:
///   - HourElapsedOffset の baseline は **CSV 全体の最初の有効な行** を採用
///     (per-car ではなく race-wide)。1 カーの lap 1 が壊れていても他カーへ
///     波及しない。
///   - 24h wrap は `Util.HourClock.offsetFrom` が内蔵しており、検証側は
///     baseline と offset を直接 `==` で比較するだけでよい。
///   - レポート順は CSV 出現順を保持(per-lap は naturally CSV 順、per-car は
///     first-seen-index で car グループをソート)。
mod Cli.Validation {

    use Util.Duration
    use Util.HourClock
    use Util.HourClock.Hour
    use RawLap.RawLap
    use RawLap.Sector

    pub enum Violation {
        /// `s1 + s2 + s3 == lapTime` を満たさない。
        /// 引数: 該当ラップ / lapTime(ms) / 合算値(ms) / 空欄だったセクタ名のリスト
        case SectorSum(RawLap, Int32, Int32, List[String])

        /// `elapsed[n] == sum(lapTime[1..=n])` を満たさない。累積和ベースなので、
        /// 一度 drift が起きた以降のラップは続けて違反になる(消えない drift)。
        /// 引数: 該当ラップ / 期待値=累積和(ms) / 実測値=elapsed(ms)
        case ElapsedDrift(RawLap, Int32, Int32)

        /// `(hour - elapsed) mod 24h` が baseline と一致しない。
        /// 引数: 該当ラップ / 基準オフセット(ms) / 実測オフセット(ms)
        case HourElapsedOffset(RawLap, Int32, Int32)

        /// hour 列が H:MM:SS.mmm 形式でパースできない。
        /// 引数: 該当ラップ / 元の生の文字列
        case HourUnparseable(RawLap, String)
    }

    /// イベント名と違反のリストから、stderr 用の文字列メッセージを生成する。
    pub def validate(eventName: String, laps: List[RawLap]): List[String] =
        detect(laps) |> List.map(v -> formatViolation(eventName, v))

    /// すべてのルールを実行し、検出された Violation のリストを返す純粋関数。
    pub def detect(laps: List[RawLap]): List[Violation] =
        let perLap = laps |> List.filterMap(lap -> resultToOption(checkSectorSum(lap)));
        let perCar = perCarViolations(laps);
        let perRace = checkHourElapsedRaceWide(laps);
        List.append(perLap, List.append(perCar, perRace))

    def resultToOption(r: Result[Violation, Unit]): Option[Violation] =
        match r {
            case Ok(_)  => None
            case Err(v) => Some(v)
        }

    /// per-car の elapsed-drift チェックを CSV 出現順 (first-seen index) で
    /// 流す。各カー内は lapNumber 昇順にソート。
    def perCarViolations(laps: List[RawLap]): List[Violation] =
        groupByCar(laps) |> List.flatMap(pair -> match pair {
            case (_, carLaps) =>
                let sorted = List.sortBy(l -> l#lapNumber, carLaps);
                checkElapsedDrift(sorted)
        })

    /// CSV 出現順を保つ groupByCar:
    ///   1. 1 パス目で carNumber → first-seen-index のマップを作る
    ///   2. 2 パス目で carNumber → 全ラップ のマップを作る
    ///   3. first-seen-index でソートしてリスト化
    def groupByCar(laps: List[RawLap]): List[(String, List[RawLap])] =
        let firstSeen = laps |> List.foldLeft(
            (acc, lap) ->
                if (Map.memberOf(lap#carNumber, acc)) acc
                else Map.insert(lap#carNumber, Map.size(acc), acc),
            Map.empty()
        );
        let grouped = laps |> List.foldLeft(
            (acc, lap) -> Map.insertWith(
                (existing, fresh) -> List.append(fresh, existing),
                lap#carNumber,
                lap :: Nil,
                acc
            ),
            Map.empty()
        );
        Map.toList(grouped) |> List.sortBy(entry -> match entry {
            case (car, _) => Map.get(car, firstSeen) |> Option.getWithDefault(0)
        })

    def checkSectorSum(lap: RawLap): Result[Violation, Unit] =
        match Duration.toMillis(lap#lapTime) {
            case None        => Ok(())
            case Some(lapMs) =>
                let (s1Ms, s1Blank) = sectorMs(lap#s1, "s1");
                let (s2Ms, s2Blank) = sectorMs(lap#s2, "s2");
                let (s3Ms, s3Blank) = sectorMs(lap#s3, "s3");
                let sum = s1Ms + s2Ms + s3Ms;
                if (sum == lapMs) Ok(())
                else
                    let blanks = (s1Blank :: s2Blank :: s3Blank :: Nil) |> List.filterMap(x -> x);
                    Err(Violation.SectorSum(lap, lapMs, sum, blanks))
        }

    /// Sector (Result[String, Int32]) を (ms, blank-label-or-None) に展開。
    /// Err は「パース不能 (空欄含む)」を意味するので 0ms 扱いにし、
    /// セクタ名(s1/s2/s3)を blank ラベルとして返して合算違反メッセージに添付する。
    def sectorMs(sector: Sector, name: String): (Int32, Option[String]) =
        match sector {
            case Ok(ms)  => (ms, None)
            case Err(_)  => (0, Some(name))
        }

    /// 累積和ベースの elapsed-drift チェック (Rust 版の `scan` と同等)。
    /// 各ラップで `running = sum(lapTime[1..=n])` を更新し、`elapsed` と一致しなければ違反。
    /// blank/未パースの lapTime / elapsed は 0 として扱う(Rust 側の挙動に合わせる)。
    /// 一度 drift が始まると以降のラップも続けて違反として報告される(隣接差分版より
    /// ノイズは多いが、相殺ドリフトを見逃さない)。
    ///
    /// 実装: `(running, acc)` のタプルを `foldLeft` で運び、最後にアキュムレータを反転。
    def checkElapsedDrift(sortedLaps: List[RawLap]): List[Violation] =
        let folded = sortedLaps |> List.foldLeft(
            (state, lap) -> match state {
                case (running, acc) =>
                    let lapMs   = Duration.toMillis(lap#lapTime) |> Option.getWithDefault(0);
                    let newRun  = running + lapMs;
                    let elapsed = Duration.toMillis(lap#elapsed) |> Option.getWithDefault(0);
                    if (newRun == elapsed) (newRun, acc)
                    else (newRun, Violation.ElapsedDrift(lap, newRun, elapsed) :: acc)
            },
            (0, Nil)
        );
        match folded {
            case (_, acc) => List.reverse(acc)
        }

    /// hour-elapsed の race-wide ベースラインチェック。
    /// baseline は CSV 出現順で最初に Hour.parse が成功した行から確定する。
    /// それ以前の行で Hour.parse が失敗した場合も `HourUnparseable` として
    /// 報告する(silent skip しない)。
    def checkHourElapsedRaceWide(laps: List[RawLap]): List[Violation] =
        // 1 パス目: baseline 確定(最初の有効な (offset, _) を探す)
        let baseline = findBaseline(laps);
        // 2 パス目: 全行をチェック
        match baseline {
            case None       =>
                // ファイル中に有効な hour が 1 行もない: HourUnparseable のみ報告
                laps |> List.filterMap(lap -> hourUnparseableOf(lap))
            case Some(base) =>
                laps |> List.filterMap(lap -> resultToOption(checkHourLine(lap, base)))
        }

    def findBaseline(laps: List[RawLap]): Option[Int32] =
        match laps {
            case Nil          => None
            case lap :: rest  =>
                match (lap#hour, Duration.toMillis(lap#elapsed)) {
                    case (Ok(h), Some(elapsedMs)) =>
                        Some(HourClock.offsetFrom(h, elapsedMs))
                    case _ => findBaseline(rest)
                }
        }

    def checkHourLine(lap: RawLap, base: Int32): Result[Violation, Unit] =
        match lap#hour {
            case Err(raw) =>
                Err(Violation.HourUnparseable(lap, raw))
            case Ok(h) =>
                match Duration.toMillis(lap#elapsed) {
                    case None => Ok(())
                    case Some(elapsedMs) =>
                        let offset = HourClock.offsetFrom(h, elapsedMs);
                        if (offset == base) Ok(())
                        else Err(Violation.HourElapsedOffset(lap, base, offset))
                }
        }

    /// baseline が見つからないケース専用の HourUnparseable 抽出。
    def hourUnparseableOf(lap: RawLap): Option[Violation] =
        match lap#hour {
            case Err(raw) => Some(Violation.HourUnparseable(lap, raw))
            case Ok(_)    => None
        }

    def formatViolation(eventName: String, v: Violation): String =
        match v {
            case Violation.SectorSum(lap, lapMs, sum, blanks) =>
                let suffix =
                    if (List.isEmpty(blanks)) ""
                    else " (blank: ${List.join(",", blanks)})";
                formatExpectedActual(eventName, lap, "sector-sum", lapMs, sum) + suffix
            case Violation.ElapsedDrift(lap, expected, actual) =>
                formatExpectedActual(eventName, lap, "elapsed-drift", expected, actual)
            case Violation.HourElapsedOffset(lap, base, offset) =>
                formatExpectedActual(eventName, lap, "hour-offset", base, offset)
            case Violation.HourUnparseable(lap, raw) =>
                "${eventName}: [car ${lap#carNumber} #${lap#lapNumber}] hour-unparseable: raw=\"${raw}\""
        }

    /// `{eventName}: [car X #N] kind: expected={fmt} ({ms}ms) actual={fmt} ({ms}ms)`
    /// raw ms を併記して grep 容易性と差分計算を両立(Rust 版と同形式)。
    def formatExpectedActual(eventName: String, lap: RawLap, kind: String, expected: Int32, actual: Int32): String =
        "${eventName}: [car ${lap#carNumber} #${lap#lapNumber}] ${kind}: expected=${formatMs(expected)} (${expected}ms) actual=${formatMs(actual)} (${actual}ms)"

    def formatMs(ms: Int32): String =
        if (ms < 0) "-" + Duration.format(0 - ms)
        else Duration.format(ms)

}
