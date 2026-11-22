use Sqlitefx.DbError
use Sqlitefx.Jdbc
use Sqlitefx.Pool

// Pool: 開いただけのプールの数字（DB 無し。open は接続しない）。

/// 開けない接続先（`/dev/null` の下にファイルは作れない）。open は接続しに行かないので、数字を読むだけなら DB は要らない。
def unreachablePool(maxConnections: Int32): Pool.Pool \ IO =
    Pool.open({ maxConnections = maxConnections | Pool.defaultConfig(Jdbc.config("jdbc:sqlite:/dev/null/none.db")) })

/// open 直後は active / idle / waiting / total が全部 0、max は設定値。
@Test
def testPoolStatsRightAfterOpen(): Unit \ {Assert, IO} =
    let pool = unreachablePool(7);
    let stats = Pool.stats(pool);
    Pool.close(pool);
    Assert.assertEq(expected = (0, 0, 0, 0, 7), (stats#active, stats#idle, stats#waiting, stats#total, stats#max))

/// 閉じた後も stats は例外を投げず、max は設定値のまま。
@Test
def testPoolStatsAfterClose(): Unit \ {Assert, IO} =
    let pool = unreachablePool(3);
    Pool.close(pool);
    let stats = Pool.stats(pool);
    Assert.assertEq(expected = (0, 0, 3), (stats#active, stats#total, stats#max))

/// 既定の設定は漏れの検出が無効（0）。
@Test
def testPoolDefaultConfigHasNoLeakDetection(): Unit \ Assert =
    let config = Pool.defaultConfig(Jdbc.config("jdbc:sqlite:/dev/null/none.db"));
    Assert.assertEq(expected = 0, config#leakDetectionThresholdMs)

/// borrow が失敗した時の分類の入力。message / cause の連鎖の中の sqlite-jdbc の result code / その時の stats。
def borrowCase(resultCode: Option[Int32], active: Int32, max: Int32): DbError.TransientKind =
    Pool.borrowFailureKind("Connection is not available, request timed out after 300ms.", resultCode, { active = active, idle = 0, waiting = 0, total = active, max = max })

/// borrow の失敗は stats と result code で分ける。
///
///   満杯（active >= max）、code 無し             → timeout（借り待ちの上限）
///   空き（active < max）、code 無し              → connectionLost（接続が作れない）
///   満杯 + CANTOPEN（14）                        → connectionLost
///   満杯 + 拡張 code の CANTOPEN（14 + 256 × n）  → connectionLost
///   満杯 + BUSY（5）                             → timeout（開けない事を示す code では無い）
///   max 0（プールが開いていない）                 → connectionLost
@Test
def testPoolBorrowFailureKind(): Unit \ Assert =
    let lost = DbError.TransientKind.ConnectionLost("Connection is not available, request timed out after 300ms.");
    let cases = List#{
        borrowCase(None, 3, 3),
        borrowCase(None, 1, 3),
        borrowCase(Some(14), 3, 3),
        borrowCase(Some(1038), 3, 3),
        borrowCase(Some(5), 3, 3),
        borrowCase(None, 0, 0)
    };
    Assert.assertEq(expected = List#{
        DbError.TransientKind.Timeout(0),
        lost,
        lost,
        lost,
        DbError.TransientKind.Timeout(0),
        lost
    }, cases)

/// 2000 未満の leakDetectionThresholdMs は 2000 に丸めて HikariCP に渡す（HikariCP が黙って無効にするのを防ぐ）。0 は無効のまま。
///
///   0    → 0
///   1    → 2000
///   1999 → 2000
///   2000 → 2000
///   5000 → 5000
@Test
def testPoolLeakDetectionThresholdIsRounded(): Unit \ {Assert, IO} =
    let config = Pool.defaultConfig(Jdbc.config("jdbc:sqlite:/dev/null/none.db"));
    let applied = List#{0, 1, 1999, 2000, 5000} |> List.map(threshold -> {
        let pool = Pool.open({ leakDetectionThresholdMs = threshold | config });
        let seen = Pool.leakDetectionThresholdMs(pool);
        Pool.close(pool);
        seen
    });
    Assert.assertEq(expected = List#{0, 2000, 2000, 2000, 5000}, applied)
