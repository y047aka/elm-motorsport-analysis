pub mod Sqlitefx.Tx {

    use Sqlitefx.Db
    use Sqlitefx.DbErr
    use Sqlitefx.DbError
    use Sqlitefx.Jdbc
    use Sqlitefx.Savepoint
    use Sqlitefx.SqlRead
    use Sqlitefx.SqlSavepoint
    use Sqlitefx.SqlWrite
    use Sqlitefx.TransientDbErr

    import java.sql.Connection
    import java.sql.SQLException

    ///
    /// BEGIN してから thunk を同じ接続で走らせ、正常なら COMMIT、Transient / DbErr のどちらかが飛べば ROLLBACK して再送出。
    /// thunk の SqlRead / SqlWrite はこの接続で実行する（内側で `Jdbc.runWithConnection` を被せるので、外側で被せ直す必要は無い）。
    ///
    /// ネストは扱わない。thunk の中でまた `withTx` を同じ接続で呼ぶと内側の COMMIT で外側も確定する。
    /// Tx の一部分だけを巻き戻したいなら `withSavepoint`。
    /// thunk の JVM の例外は `DbErr` の `Other` にして ROLLBACK する。fatal は ROLLBACK を送らずに投げ直す
    /// （接続は呼び手の物で捨てられないので、捨てるのは呼び手。プールの接続なら `Pool.withLazyTx*` を使う）。
    ///
    pub def withTx(conn: Connection, thunk: Unit -> a \ ef): a \ (ef - {SqlRead, SqlWrite, SqlSavepoint}) + {IO, TransientDbErr, DbErr} =
        begin(conn);
        let watch = Jdbc.unwatched();
        match Jdbc.watched(watch, () -> DbError.runWithKind(() -> Jdbc.runWithConnectionWatched(() -> conn, watch, () -> Db.guard(thunk)))) {
            case Ok(value) => { commit(conn); value }
            case Err(kind) => { discard rollback(conn); DbError.raise(kind) }
        }

    ///
    /// Tx の中の一部分だけを SAVEPOINT で囲む。`SAVEPOINT name` → thunk → 成功なら `RELEASE SAVEPOINT name` で `Ok`、
    /// thunk が `TransientDbErr` / `DbErr` を投げたら `ROLLBACK TO SAVEPOINT name` で戻して `Err`。中の失敗（BUSY、制約違反）は外の Tx に及ばない。
    /// 読むだけ（`DbRead`）の Tx でも張れる。`RELEASE` / `ROLLBACK TO` 自体の失敗は値にせず、外の Tx の失敗として投げる。
    ///
    /// ```
    /// Tx.withSavepoint("import_row", () -> insertImportedRow(row))
    /// //   : Result[Failure, Unit] \ DbWrite + SqlSavepoint + RawSql
    /// ```
    ///
    /// name は `Savepoint.isValidName`（`^[a-z_][a-z0-9_]*$`、63 文字まで）を通った物だけ SQL に入る。それ以外は SQL を出さずに `Err`。
    ///
    /// WhyNot: 名前が不正なときに `DbErr` を投げないのは、呼ぶ側にとっては「この部分の失敗」であって外の Tx を壊す理由が無いため。
    ///
    /// WhyNot: `Db.attempt` と同じ `Failure` で返すのは、中で受けたい失敗に BUSY（Transient の Timeout）と制約違反（Permanent）の両方があり、呼ぶ側が一時障害と永続の失敗を分けて扱えるようにするため。
    ///
    pub def withSavepoint(name: String, thunk: Unit -> a \ ef): Result[DbError.Failure, a] \ (ef - {TransientDbErr, DbErr}) + {SqlSavepoint, TransientDbErr, DbErr} =
        if (not Savepoint.isValidName(name))
            Err(DbError.Failure.Permanent(DbError.DbErrorKind.Other("invalid savepoint name: ${name} (${Savepoint.nameRule()})")))
        else {
            control(Savepoint.Command.Savepoint(name));
            match DbError.runWithFailure(thunk) {
                case Ok(value)    => { control(Savepoint.Command.Release(name)); Ok(value) }
                case Err(failure) => { control(Savepoint.Command.RollbackTo(name)); Err(failure) }
            }
        }

    ///
    /// SAVEPOINT の命令を 1 つ発行し、handler が返した失敗を呼び出し側の文脈で op にする。
    ///
    def control(command: Savepoint.Command): Unit \ {SqlSavepoint, TransientDbErr, DbErr} =
        match SqlSavepoint.control(command) {
            case Ok(())   => ()
            case Err(kind) => DbError.raise(kind)
        }

    ///
    /// autocommit を切って Tx を始める。`Pool.withLazyTx` のように Tx の形を自分で組む所から呼ぶ。
    ///
    pub def begin(conn: Connection): Unit \ {IO, TransientDbErr, DbErr} =
        try {
            conn.setAutoCommit(false)
        } catch {
            case e: SQLException => Jdbc.raiseSqlException(e)
        }

    ///
    /// COMMIT して autocommit に戻す。COMMIT 自体の失敗（他の接続のロックで BUSY など）も翻訳する。
    /// 失敗したら ROLLBACK して autocommit に戻してから投げる。戻さないと、次の文が誰も COMMIT しない Tx に入る。
    ///
    /// WhyNot: PG のように COMMIT の前に Tx が aborted かを見ないのは、SQLite は失敗した文だけを巻き戻して Tx を続けるから。
    /// Tx ごと巻き戻す失敗（SQLITE_FULL、SQLITE_IOERR など）の後では SQLite の側に Tx が無く、COMMIT が「no transaction is active」で失敗するので、書いた物が黙って消えたまま Ok で返る道は無い。
    ///
    pub def commit(conn: Connection): Unit \ {IO, TransientDbErr, DbErr} =
        try {
            conn.commit();
            conn.setAutoCommit(true)
        } catch {
            case e: SQLException => { discard rollback(conn); Jdbc.raiseSqlException(e) }
        }

    ///
    /// ROLLBACK して autocommit に戻す。成功したか（ROLLBACK と autocommit の戻しの両方が通ったか）を返す。
    /// 失敗した接続は Tx の途中のままなので、プールの接続なら返さずに捨てる（`Pool.evict`）。
    ///
    /// WhyNot: 失敗を例外にしないのは、呼ぶ所は元のエラーを再送出する途中で、ROLLBACK の失敗でそれを上書きしたくないため。
    ///
    pub def rollback(conn: Connection): Bool \ IO =
        try {
            conn.rollback();
            conn.setAutoCommit(true);
            true
        } catch {
            case _: SQLException => false
        }

}
